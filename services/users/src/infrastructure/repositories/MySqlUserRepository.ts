import { ResultSetHeader, RowDataPacket } from "mysql2";
import { User, UserRole } from "../../domain/entities/User.js";
import {
  UserRepository,
  UserUpdate,
} from "../../domain/repositories/UserRepository.js";
import { pool } from "../../config/database.js";

interface UserRow extends RowDataPacket {
  id: number;
  names: string;
  surnames: string;
  code: string;
  email: string;
  password: string;
  school: string;
  cycle: number;
  role: UserRole;
  created_at: Date;
}

export class MySqlUserRepository implements UserRepository {
  async update(id: number, input: UserUpdate): Promise<void> {
    const columns: Partial<Record<keyof UserUpdate, string>> = {
      names: "names",
      surnames: "surnames",
      code: "code",
      school: "school",
      cycle: "cycle",
    };
    const assignments: string[] = [];
    const values: Array<string | number> = [];

    for (const key of Object.keys(input) as Array<keyof UserUpdate>) {
      const column = columns[key];
      const value = input[key];

      if (column && value !== undefined) {
        assignments.push(`${column} = ?`);
        values.push(value);
      }
    }

    if (assignments.length === 0) {
      return;
    }

    values.push(id);

    await pool.execute(
      `UPDATE users SET ${assignments.join(", ")} WHERE id = ?`,
      values,
    );
  }

  async save(user: User): Promise<User> {
    const [result] = await pool.execute<ResultSetHeader>(
      `
        INSERT INTO users (
          names,
          surnames,
          code,
          email,
          password,
          school,
          cycle,
          role,
          created_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      `,
      [
        user.getNames(),
        user.getSurnames(),
        user.getCode(),
        user.getEmail(),
        user.getPassword(),
        user.getSchool(),
        user.getCycle(),
        user.getRole(),
        user.getCreatedAt(),
      ],
    );

    user.assignId(result.insertId);

    return user;
  }

  async findById(id: number): Promise<User | null> {
    const [rows] = await pool.query<UserRow[]>(
      `
        SELECT
          id,
          names,
          surnames,
          code,
          email,
          password,
          school,
          cycle,
          role,
          created_at
        FROM users
        WHERE id = ?
      `,
      [id],
    );

    if (rows.length === 0) {
      return null;
    }

    return this.toDomain(rows[0]);
  }

  async findByEmail(email: string): Promise<User | null> {
    const [rows] = await pool.query<UserRow[]>(
      `
        SELECT
          id,
          names,
          surnames,
          code,
          email,
          password,
          school,
          cycle,
          role,
          created_at
        FROM users
        WHERE email = ?
      `,
      [email],
    );

    if (rows.length === 0) {
      return null;
    }

    return this.toDomain(rows[0]);
  }

  async findByCode(code: string): Promise<User | null> {
    const [rows] = await pool.query<UserRow[]>(
      `
        SELECT
          id,
          names,
          surnames,
          code,
          email,
          password,
          school,
          cycle,
          role,
          created_at
        FROM users
        WHERE code = ?
      `,
      [code],
    );

    if (rows.length === 0) {
      return null;
    }

    return this.toDomain(rows[0]);
  }

  async findAll(): Promise<User[]> {
    const [rows] = await pool.query<UserRow[]>(
      `
        SELECT
          id,
          names,
          surnames,
          code,
          email,
          password,
          school,
          cycle,
          role,
          created_at
        FROM
        users
        ORDER BY id
      `,
    );

    return rows.map((row) => this.toDomain(row));
  }

  private toDomain(row: UserRow): User {
    return new User({
      id: row.id,
      names: row.names,
      surnames: row.surnames,
      code: row.code,
      email: row.email,
      password: row.password,
      school: row.school,
      cycle: row.cycle,
      role: row.role,
      createdAt: row.created_at,
    });
  }
}
