import { Module } from '@nestjs/common';
import { ProfileController } from './profile.controller';

/** The User's own profile: `/me`. */
@Module({ controllers: [ProfileController] })
export class ProfileModule {}
