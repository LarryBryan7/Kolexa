import { Controller, Get, Post, Body, Param, ParseIntPipe } from '@nestjs/common';
import { IsString, IsNumber, IsOptional, IsInt, IsPositive, IsEnum } from 'class-validator';
import { CouponsService } from './coupons.service';
import { CurrentUser, UserPayload } from '../../common/decorators/current-user.decorator';

class CreateCampaignDto {
  @IsString() name: string;
  @IsOptional() @IsString() description?: string;
  @IsEnum(['percentage', 'fixed']) discountType: 'percentage' | 'fixed';
  @IsNumber() discountValue: number;
  @IsOptional() @IsString() partnerName?: string;
  @IsOptional() @IsString() partnerLogo?: string;
  @IsString() validFrom: string;
  @IsString() validUntil: string;
  @IsOptional() @IsInt() maxRedemptions?: number;
  @IsOptional() @IsInt() maxPerUser?: number;
}

@Controller('coupons')
export class CouponsController {
  constructor(private readonly service: CouponsService) {}

  @Post('campaigns')
  createCampaign(@Body() dto: CreateCampaignDto, @CurrentUser() user: UserPayload) {
    return this.service.createCampaign(
      { ...dto, schoolId: user.schoolId ?? BigInt(0) },
      user.sub,
    );
  }

  @Get('available')
  getAvailable(@CurrentUser() user: UserPayload) {
    return this.service.getAvailableCoupons(user.sub, user.schoolId ?? BigInt(0));
  }

  @Post(':campaignId/redeem')
  redeem(
    @Param('campaignId', ParseIntPipe) campaignId: number,
    @CurrentUser() user: UserPayload,
  ) {
    return this.service.redeemCoupon(campaignId, user.sub);
  }

  @Get('my')
  getMyCoupons(@CurrentUser() user: UserPayload) {
    return this.service.getMyCoupons(user.sub);
  }
}
