import fs from 'fs';
import path from 'path';
import { EvidenceStep } from './types';

export function evidenceFolderFor(runFolder: string, competitor: string, state: string, scenarioId: string) {
  return path.join(runFolder, 'evidence', competitor, state, scenarioId);
}

export async function captureScreenshot(page: any, folder: string, stepName: string, stepIndex: number): Promise<EvidenceStep> {
  fs.mkdirSync(folder, { recursive: true });
  const fileName = `step_${String(stepIndex).padStart(2, '0')}_${stepName}.png`;
  const filePath = path.join(folder, fileName);

  await page.screenshot({ path: filePath, fullPage: true });

  return {
    step: stepName,
    path: filePath,
    timestamp: new Date().toISOString(),
  };
}
