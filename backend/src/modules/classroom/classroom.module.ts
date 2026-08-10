import { Module } from '@nestjs/common';
import { ClassroomController } from './classroom.controller';
import { ClassroomService } from './classroom.service';

@Module({
  controllers: [ClassroomController],
  providers: [ClassroomService],
  exports: [ClassroomService],
})
export class ClassroomModule {}
