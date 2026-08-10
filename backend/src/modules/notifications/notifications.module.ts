import { Global, Module } from '@nestjs/common';
import { NotificationsService } from './notifications.service';

// @Global: hace que NotificationsService esté disponible en toda la app
// sin necesidad de importar NotificationsModule en cada módulo que lo use.
@Global()
@Module({
  providers: [NotificationsService],
  exports: [NotificationsService],
})
export class NotificationsModule {}
