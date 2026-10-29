import { createZodDto } from 'nestjs-zod';
import { z } from 'zod';
import type { User } from '../database/schema';

/** The User as the app sees it: `GET /me` and the `user` of every sign-in. */
export const userProfileSchema = z.object({
  id: z.uuid(),
  name: z.string(),
  email: z.string(),
  // A bare `z.string().nullable()` comes out of nestjs-zod as an array in the
  // OpenAPI 3.0 document; any metadata on the inner string avoids it.
  phone: z
    .string()
    .meta({ example: '+5511987654321' })
    .nullable()
    .describe('WhatsApp number (E.164); null until the first listing'),
  donationLocation: z
    .object({ neighborhood: z.string() })
    .nullable()
    .describe('Null until the first listing; the coordinates never come back'),
});

export class UserProfile extends createZodDto(userProfileSchema) {}

export function toUserProfile(user: User): z.infer<typeof userProfileSchema> {
  return {
    id: user.id,
    name: user.name,
    email: user.email,
    phone: user.phone,
    donationLocation:
      user.donationLocation === null
        ? null
        : { neighborhood: user.donationNeighborhood ?? '' },
  };
}
