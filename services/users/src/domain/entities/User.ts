export type UserRole = "ESTUDIANTE" | "PERSONAL_UNAYOE" | "ADMINISTRADOR";

export interface UserProps {
  id?: number;
  names: string;
  surnames: string;
  code: string;
  email: string;
  password: string;
  school: string;
  cycle: number;
  role: UserRole;
  createdAt: Date;
}

export class User {
  private id: number | undefined;
  private names: string;
  private surnames: string;
  private code: string;
  private email: string;
  private password: string;
  private school: string;
  private cycle: number;
  private role: UserRole;
  private createdAt: Date;

  constructor(props: UserProps) {
    this.validate(props);

    this.id = props.id;
    this.names = props.names;
    this.surnames = props.surnames;
    this.code = props.code;
    this.email = props.email;
    this.password = props.password;
    this.school = props.school;
    this.cycle = props.cycle;
    this.role = props.role;
    this.createdAt = props.createdAt;
  }

  private validate(props: UserProps): void {}

  getId(): number | undefined {
    return this.id;
  }

  assignId(id: number): void {
    if (this.id) {
      throw new Error("El usuario ya tiene un ID asignado");
    }

    this.id = id;
  }

  getNames(): string {
    return this.names;
  }

  getSurnames(): string {
    return this.surnames;
  }

  getCode(): string {
    return this.code;
  }

  getEmail(): string {
    return this.email;
  }

  getPassword(): string {
    return this.password;
  }

  getSchool(): string {
    return this.school;
  }

  getCycle(): number {
    return this.cycle;
  }

  getRole(): UserRole {
    return this.role;
  }

  getCreatedAt(): Date {
    return this.createdAt;
  }
}
