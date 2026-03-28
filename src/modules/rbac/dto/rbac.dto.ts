import { IsString, IsNotEmpty, IsUUID, IsArray } from 'class-validator';

export class UpdateRolePermissionsDto {
  @IsArray()
  @IsUUID(undefined, { each: true })
  permissionIds!: string[];
}
