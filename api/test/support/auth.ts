import type { INestApplication } from '@nestjs/common';
import request from 'supertest';
import type { App } from 'supertest/types';
import { DATABASE, type Database } from '../../src/database/database.module';
import type { FakeOutbox } from './fake-outbox';

/** The body of every answer that signs the User in. */
export interface AuthTokensBody {
  accessToken: string;
  refreshToken: string;
  user: {
    id: string;
    name: string;
    email: string;
    phone: string | null;
    donationLocation: { neighborhood: string } | null;
  };
}

export interface NewAccount {
  name: string;
  email: string;
  password: string;
}

let accounts = 0;

/** A fresh account for one test: a unique e-mail and a valid password. */
export function newAccount(overrides: Partial<NewAccount> = {}): NewAccount {
  accounts += 1;
  return {
    name: 'Marina Souza',
    email: `pessoa${String(accounts)}.${String(Date.now())}@email.com`,
    password: 'senha-boa-123',
    ...overrides,
  };
}

/** `POST /v1/auth/signup`, expecting the `202`. */
export async function signUp(
  app: INestApplication<App>,
  account: NewAccount,
): Promise<void> {
  await request(app.getHttpServer())
    .post('/v1/auth/signup')
    .send(account)
    .expect(202);
}

/**
 * Signs up and confirms the e-mail with the code from [outbox], the way the
 * app does: the resulting confirmed User and its tokens.
 */
export async function signUpAndVerify(
  app: INestApplication<App>,
  outbox: FakeOutbox,
  account: NewAccount = newAccount(),
): Promise<AuthTokensBody> {
  await signUp(app, account);
  const response = await request(app.getHttpServer())
    .post('/v1/auth/verify-email')
    .send({
      email: account.email,
      code: outbox.lastCodeTo(account.email, 'signup-code'),
    })
    .expect(200);
  return response.body as AuthTokensBody;
}

/**
 * The app's database, for the few tests that must build a state the API does
 * not allow through the front door (an expired code, for instance).
 */
export function databaseOf(app: INestApplication<App>): Database {
  return app.get<Database>(DATABASE);
}
