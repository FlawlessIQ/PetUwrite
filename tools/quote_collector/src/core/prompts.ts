import readline from 'readline';

export async function waitForEnter(message: string): Promise<void> {
  // eslint-disable-next-line no-console
  console.log(message);

  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  await new Promise<void>((resolve) => {
    rl.question('', () => {
      rl.close();
      resolve();
    });
  });
}

export async function promptForText(message: string): Promise<string> {
  // eslint-disable-next-line no-console
  console.log(message);

  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  const answer = await new Promise<string>((resolve) => {
    rl.question('> ', (val) => {
      rl.close();
      resolve(val);
    });
  });

  return answer;
}

export function parseMoneyToNumber(raw: string): number | null {
  const cleaned = raw.trim();
  if (!cleaned) return null;

  // Accept formats like "$42.13", "42.13", "42", "USD 42.13".
  const match = cleaned.replace(/,/g, '').match(/(\d+(?:\.\d{1,2})?)/);
  if (!match) return null;

  const n = Number(match[1]);
  return Number.isFinite(n) ? n : null;
}
