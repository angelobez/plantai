import { sql } from 'drizzle-orm';
import { maintenanceState } from '../database/schema';
import type { MaintenanceContext } from './maintenance';
import { CU_SECONDS_PER_CU_HOUR } from './neon-api';

/** The Neon Free plan suspends the compute past this, until the next cycle. */
export const NEON_FREE_CU_HOURS = 100;

/** Above this, Ângelo is told to move to the Launch plan. */
export const NEON_ALERT_CU_HOURS = 80;

export interface NeonUsageReport {
  /** Rounded to two decimals. */
  cuHours: number;
  /** The start of the billing cycle, as Neon sends it. */
  periodStart: string;
  /** Whether this run sent the alert. */
  alerted: boolean;
}

/** `1234.5` as `1.234,5`, as Ângelo reads numbers. */
const brazilian = (value: number) =>
  value.toLocaleString('pt-BR', { maximumFractionDigits: 1 });

/**
 * Reads the CU-hours of the current Neon billing cycle and, above
 * {@link NEON_ALERT_CU_HOURS}, publishes an alert, once per cycle. The cycle
 * is marked as alerted in the same transaction that publishes, so a failed
 * publish leaves it unmarked and the next run tries again.
 */
export async function checkNeonUsage({
  db,
  neon,
  alerts,
}: MaintenanceContext): Promise<NeonUsageReport> {
  const usage = await neon.projectUsage();
  const cuHours = usage.computeTimeSeconds / CU_SECONDS_PER_CU_HOUR;
  const periodStart = usage.consumptionPeriodStart;
  const report = {
    cuHours: Math.round(cuHours * 100) / 100,
    periodStart,
    alerted: false,
  };
  if (cuHours <= NEON_ALERT_CU_HOURS) return report;

  return db.transaction(async (tx) => {
    // Takes the cycle only if it is not the one already alerted.
    const claimed = await tx
      .insert(maintenanceState)
      .values({ key: 'neon-usage-alerted-period', value: periodStart })
      .onConflictDoUpdate({
        target: maintenanceState.key,
        set: { value: periodStart, updatedAt: sql`now()` },
        setWhere: sql`${maintenanceState.value} <> ${periodStart}`,
      })
      .returning({ key: maintenanceState.key });
    if (claimed.length === 0) return report;

    await alerts.publish({
      // ASCII only: SNS refuses anything else in the subject.
      subject: `PlantAi: Neon passou de ${String(NEON_ALERT_CU_HOURS)} CU-horas no mes`,
      message: [
        `O banco do PlantAí no Neon já usou ${brazilian(cuHours)} CU-horas no ciclo de cobrança que começou em ${periodStart}.`,
        `No plano Free, o compute fica suspenso ao passar de ${String(NEON_FREE_CU_HOURS)} CU-horas, até o próximo ciclo, e a API para de funcionar.`,
        'Troque para o plano Launch no console do Neon (Billing) antes disso.',
        '',
        'Este aviso vem uma vez por ciclo, da rotina de manutenção da API.',
      ].join('\n'),
    });
    return { ...report, alerted: true };
  });
}
