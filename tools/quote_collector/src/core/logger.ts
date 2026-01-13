import fs from 'fs';
import path from 'path';

export class Logger {
  private readonly logPath: string;

  constructor(private readonly runFolder: string) {
    this.logPath = path.join(runFolder, 'runner.log');
  }

  info(message: string) {
    this.write('INFO', message);
  }

  warn(message: string) {
    this.write('WARN', message);
  }

  error(message: string) {
    this.write('ERROR', message);
  }

  private write(level: string, message: string) {
    const line = `${new Date().toISOString()} [${level}] ${message}`;
    // Console for operator
    // eslint-disable-next-line no-console
    console.log(line);

    fs.mkdirSync(this.runFolder, { recursive: true });
    fs.appendFileSync(this.logPath, line + '\n');
  }
}
