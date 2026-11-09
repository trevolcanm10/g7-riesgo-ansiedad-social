import { User, UserRole } from "../../domain/entities/User.js";

export interface UserResponseDTO {
  id: number;
  names: string;
  surnames: string;
  code: string;
  email: string;
  school: string;
  cycle: number;
  role: UserRole;
  createdAt: Date;
}

export const toUserResponseDTO = (user: User): UserResponseDTO => {
  return {
    id: user.getId()!,
    names: user.getNames(),
    surnames: user.getSurnames(),
    code: user.getCode(),
    email: user.getEmail(),
    school: user.getSchool(),
    cycle: user.getCycle(),
    role: user.getRole(),
    createdAt: user.getCreatedAt(),
  };
};
