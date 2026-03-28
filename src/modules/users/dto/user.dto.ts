import { IsEmail, IsNotEmpty, IsString, IsUUID, IsOptional } from 'class-validator';

export class CreateUserDto {
  @IsEmail()
  email!: string;

  @IsString()
  @IsNotEmpty()
  fullName!: string;

  @IsUUID()
  roleId!: string;
}

export class UpdateUserDto {
  @IsOptional() @IsString() fullName?: string;
  @IsOptional() @IsUUID() roleId?: string;
  @IsOptional() @IsString() phone?: string;
}
