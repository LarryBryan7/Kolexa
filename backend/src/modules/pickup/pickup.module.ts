import { Module } from '@nestjs/common';
import { PickupController } from './pickup.controller';
import { PickupService } from './pickup.service';
import { PrismaModule } from '../../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  controllers: [PickupController],
  providers: [PickupService],
  exports: [PickupService],
})
export class PickupModule {}
