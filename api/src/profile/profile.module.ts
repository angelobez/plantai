import { Module } from '@nestjs/common';
import { ProfileController } from './profile.controller';
import { ProfileService } from './profile.service';

/** The User's own profile: `/me`. */
@Module({ controllers: [ProfileController], providers: [ProfileService] })
export class ProfileModule {}
