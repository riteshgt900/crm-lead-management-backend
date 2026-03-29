import { Module } from '@nestjs/common';
import { SlasController } from './slas.controller';
import { SlasService } from './slas.service';
import { DatabaseModule } from '../../database/database.module';

@Module({
  imports: [DatabaseModule],
  controllers: [SlasController],
  providers: [SlasService],
  exports: [SlasService],
})
export class SlasModule {}
