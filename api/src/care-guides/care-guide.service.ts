import { Inject, Injectable, Logger } from '@nestjs/common';
import { and, asc, desc, eq, sql } from 'drizzle-orm';
import { DATABASE, type Database } from '../database/database.module';
import {
  careGuides,
  normalized,
  species,
  speciesNames,
} from '../database/schema';
import { DomainError } from '../errors/domain-error';
import {
  type CareGuideContent,
  careGuideContentSchema,
} from './care-guide-content';
import type { CareGuideFieldsResponse } from './care-guide.dto';
import { CareGuideWriter, type WrittenCareGuide } from './care-guide-writer';

/** A `generating` row older than this counts as abandoned. */
export const CARE_GUIDE_GENERATION_TIMEOUT_SECONDS = 60;

/** The `Retry-After` of `CARE_GUIDE_GENERATING`. */
export const CARE_GUIDE_RETRY_AFTER_SECONDS = 3;

/** What {@link CareGuideService.ensure} found or did. */
export type CareGuideOutcome =
  /** [generated] is true when this call wrote it. */
  | { status: 'ready'; content: CareGuideContent; generated: boolean }
  /** Claude failed this time; the row is `failed`. */
  | { status: 'unavailable'; reason: string }
  /** Another call is writing it right now. */
  | { status: 'generating' };

function messageOf(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

/**
 * The care guide of each species, written once by Claude and the same for
 * everyone. {@link ensure} is the one generation function: the API (species
 * and plant screens) and `npm run catalog:load` all go through it.
 *
 * Constructor parameters use explicit `@Inject`, because the load script runs
 * on tsx, which emits no decorator metadata.
 */
@Injectable()
export class CareGuideService {
  private readonly logger = new Logger(CareGuideService.name);

  constructor(
    @Inject(DATABASE) private readonly db: Database,
    @Inject(CareGuideWriter) private readonly writer: CareGuideWriter,
  ) {}

  /**
   * The care guide of [speciesId], generating it when there is none or the
   * last one failed. Only the call that wins the reservation asks Claude;
   * one that finds another call generating answers `generating`. A
   * `generating` row older than {@link CARE_GUIDE_GENERATION_TIMEOUT_SECONDS}
   * counts as failed. [requestedBy] is the User who caused the generation
   * (null for the seed load). `NOT_FOUND` when the species does not exist.
   */
  async ensure(
    speciesId: string,
    requestedBy: string | null,
  ): Promise<CareGuideOutcome> {
    const current = await this.current(speciesId);
    if (current === undefined) throw new DomainError('NOT_FOUND');
    if (current.status === 'ready') return current;

    if (!(await this.reserve(speciesId, requestedBy))) {
      // Lost the reservation; the winner may have finished meanwhile.
      const now = await this.current(speciesId);
      return now?.status === 'ready' ? now : { status: 'generating' };
    }
    return this.generate(speciesId);
  }

  /**
   * The care-guide fields of a response, from {@link ensure}. While another
   * request is generating, throws `CARE_GUIDE_GENERATING` (`202` with
   * `Retry-After`) for the client to try again.
   */
  async forResponse(
    speciesId: string,
    requestedBy: string,
  ): Promise<CareGuideFieldsResponse> {
    const outcome = await this.ensure(speciesId, requestedBy);
    switch (outcome.status) {
      case 'ready':
        return { careGuide: outcome.content, careGuideStatus: 'ready' };
      case 'unavailable':
        return { careGuide: null, careGuideStatus: 'unavailable' };
      case 'generating':
        throw new DomainError('CARE_GUIDE_GENERATING', {
          retryAfterSeconds: CARE_GUIDE_RETRY_AFTER_SECONDS,
        });
    }
  }

  /**
   * The ready guide, `pending` for any other state or none, or undefined
   * when the species does not exist.
   */
  private async current(
    speciesId: string,
  ): Promise<
    | { status: 'ready'; content: CareGuideContent; generated: false }
    | { status: 'pending' }
    | undefined
  > {
    const [row] = await this.db
      .select({ status: careGuides.status, content: careGuides.content })
      .from(species)
      .leftJoin(careGuides, eq(careGuides.speciesId, species.id))
      .where(eq(species.id, speciesId));
    if (!row) return undefined;
    if (row.status !== 'ready') return { status: 'pending' };
    return {
      status: 'ready',
      content: careGuideContentSchema.parse(row.content),
      generated: false,
    };
  }

  /**
   * Marks the guide `generating` for this call, in one statement: it wins
   * when there is no row, the row `failed`, or its generation was abandoned.
   */
  private async reserve(
    speciesId: string,
    requestedBy: string | null,
  ): Promise<boolean> {
    const rows = await this.db
      .insert(careGuides)
      .values({
        speciesId,
        status: 'generating',
        model: this.writer.model,
        promptVersion: this.writer.promptVersion,
        requestedBy,
        startedAt: sql`now()`,
      })
      .onConflictDoUpdate({
        target: careGuides.speciesId,
        set: {
          status: 'generating',
          content: null,
          model: sql.raw('excluded.model'),
          promptVersion: sql.raw('excluded.prompt_version'),
          requestedBy: sql.raw('excluded.requested_by'),
          startedAt: sql.raw('excluded.started_at'),
          generatedAt: null,
        },
        setWhere: sql`${careGuides.status} = 'failed' OR (${careGuides.status} = 'generating' AND ${careGuides.startedAt} < now() - make_interval(secs => ${CARE_GUIDE_GENERATION_TIMEOUT_SECONDS}))`,
      })
      .returning({ speciesId: careGuides.speciesId });
    return rows.length > 0;
  }

  /** Asks Claude, then keeps the guide (and its name) or the failure. */
  private async generate(speciesId: string): Promise<CareGuideOutcome> {
    const [row] = await this.db
      .select({ scientificName: species.scientificName })
      .from(species)
      .where(eq(species.id, speciesId));
    const names = await this.db
      .select({ name: speciesNames.name })
      .from(speciesNames)
      .where(eq(speciesNames.speciesId, speciesId))
      .orderBy(desc(speciesNames.isPrimary), asc(speciesNames.nameNormalized));

    let written: WrittenCareGuide;
    try {
      if (!row) throw new Error('The species is gone');
      written = await this.writer.write({
        scientificName: row.scientificName,
        knownNames: names.map((name) => name.name),
      });
    } catch (error) {
      const reason = messageOf(error);
      this.logger.warn(
        `Care guide of species ${speciesId} not written: ${reason}`,
      );
      await this.db
        .update(careGuides)
        .set({ status: 'failed' })
        .where(
          and(
            eq(careGuides.speciesId, speciesId),
            eq(careGuides.status, 'generating'),
          ),
        );
      return { status: 'unavailable', reason };
    }

    await this.db.transaction(async (tx) => {
      await tx
        .update(careGuides)
        .set({
          status: 'ready',
          content: written.content,
          model: written.model,
          promptVersion: this.writer.promptVersion,
          generatedAt: sql`now()`,
        })
        .where(eq(careGuides.speciesId, speciesId));
      await this.keepCommonName(tx, speciesId, written.content.commonName);
    });
    return { status: 'ready', content: written.content, generated: true };
  }

  /**
   * Claude's common name becomes the primary one of a species without one,
   * and an alternative one when the species does not have it yet. Names are
   * compared accents and capitals aside, like the search.
   */
  private async keepCommonName(
    tx: Parameters<Parameters<Database['transaction']>[0]>[0],
    speciesId: string,
    commonName: string,
  ): Promise<void> {
    const names = await tx
      .select({
        id: speciesNames.id,
        isPrimary: speciesNames.isPrimary,
        same: sql<boolean>`${speciesNames.nameNormalized} = ${normalized(commonName)}`,
      })
      .from(speciesNames)
      .where(eq(speciesNames.speciesId, speciesId));
    const same = names.find((name) => name.same);
    const hasPrimary = names.some((name) => name.isPrimary);

    if (!hasPrimary && same) {
      await tx
        .update(speciesNames)
        .set({ isPrimary: true })
        .where(eq(speciesNames.id, same.id));
    } else if (!same) {
      await tx
        .insert(speciesNames)
        .values({ speciesId, name: commonName, isPrimary: !hasPrimary });
    }
  }
}
