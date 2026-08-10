import { Module } from '@nestjs/common';
import { AnecdotesController } from './anecdotes.controller';
import { AnecdotesService } from './anecdotes.service';
import { PrismaModule } from '../../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  controllers: [AnecdotesController],
  providers: [AnecdotesService],
  exports: [AnecdotesService],
})
export class AnecdotesModule {}
