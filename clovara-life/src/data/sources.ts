import type { Citation } from './types'

/**
 * Every published source the data file leans on, in one place.
 *
 * IMPORTANT: these studies do not measure the same thing. `metric` is carried
 * on every citation and must never be dropped — "life expectancy at age 0"
 * (which includes puppy and juvenile deaths) runs systematically lower than
 * "median survival" or "median age at death". Figures from different studies
 * are never averaged together anywhere in this codebase.
 */

export const MCMILLAN_2024: Citation = {
  label: 'McMillan et al. 2024, Scientific Reports 14:531 — 584,734 UK dogs',
  url: 'https://www.nature.com/articles/s41598-023-50458-w',
  metric: 'median survival (Kaplan–Meier)',
}

export const TENG_DOG_2022: Citation = {
  label: 'Teng et al. 2022, Scientific Reports 12:6415 — VetCompass UK life tables',
  url: 'https://www.nature.com/articles/s41598-022-10341-6',
  metric: 'life expectancy at age 0',
}

export const MONTOYA_2023: Citation = {
  label: 'Montoya et al. 2023, Front Vet Sci 10:1082102 — 13.3M US dogs, 2.4M US cats (Banfield)',
  url: 'https://www.frontiersin.org/journals/veterinary-science/articles/10.3389/fvets.2023.1082102/full',
  metric: 'life expectancy at birth',
}

export const TENG_CAT_2024: Citation = {
  label: 'Teng et al. 2024, J Feline Med Surg 26(5) — VetCompass UK feline life tables',
  url: 'https://journals.sagepub.com/doi/10.1177/1098612X241234556',
  metric: 'life expectancy at age 0',
}

export const ONEILL_CAT_2015: Citation = {
  label: "O'Neill et al. 2015, J Feline Med Surg — 118,016 UK cats",
  url: 'https://journals.sagepub.com/doi/10.1177/1098612X14536176',
  metric: 'median age at death',
}

export const KEALY_2002: Citation = {
  label: 'Kealy et al. 2002, JAVMA 220(9) — Purina lifetime study, 48 Labradors',
  url: 'https://avmajournals.avma.org/view/journals/javma/220/9/javma.2002.220.1315.xml',
  metric: 'median lifespan, paired-feeding trial',
  figure: '13.0 yr lean-fed vs 11.2 yr control',
}

export const LAWLER_2008: Citation = {
  label: 'Lawler et al. 2008, Br J Nutr 99(4):793–805 — 20-year review of the Purina study',
  url: 'https://www.cambridge.org/core/journals/british-journal-of-nutrition/article/diet-restriction-and-ageing-in-the-dog-major-observations-over-two-decades/3DDCC1DDF5A7D85518684AA687FBA63E',
  metric: 'median lifespan',
  figure: '13.0 vs 11.2 years',
}

export const SMITH_2006: Citation = {
  label: 'Smith et al. 2006, JAVMA 229(5) — hip osteoarthritis in the Purina cohort',
  url: 'https://avmajournals.avma.org/view/journals/javma/229/5/javma.229.5.690.xml',
  metric: 'median age at onset of radiographic hip OA',
  figure: '6 yr control vs 12 yr lean-fed',
}

export const SALT_2019: Citation = {
  label: 'Salt et al. 2019, J Vet Intern Med 33(1):89–99 — 50,787 neutered US dogs',
  url: 'https://academic.oup.com/jvim/article/33/1/89/8447813',
  metric: 'median lifespan difference, overweight vs normal body condition',
  figure: 'from −0.4 yr (German Shepherd) to −2.5 yr (Yorkshire Terrier)',
}

export const TENG_BCS_2018: Citation = {
  label: 'Teng et al. 2018, J Feline Med Surg — body condition and survival in 2,609 cats',
  url: 'https://journals.sagepub.com/doi/10.1177/1098612X17752198',
  metric: 'hazard ratio by 9-point body condition score',
  figure: 'thin cats at clearly higher risk; BCS 7–8 not significantly associated',
}

export const AAHA_DENTAL_2019: Citation = {
  label: 'AAHA Dental Care Guidelines for Dogs and Cats, 2019',
  url: 'https://www.aaha.org/wp-content/uploads/globalassets/02-guidelines/dental/aaha_dental_guidelines.pdf',
  metric: 'clinical guideline',
}

export const GLICKMAN_2011: Citation = {
  label: 'Glickman et al. 2011, Prev Vet Med — periodontal disease and kidney disease in 164,706 dogs',
  url: 'https://pubmed.ncbi.nlm.nih.gov/21345505/',
  metric: 'hazard ratio for azotaemic chronic kidney disease',
  figure: 'HR 1.8 (stage 1) to 2.7 (stage 3/4)',
}

export const TREVEJO_2018: Citation = {
  label: 'Trevejo et al. 2018, JAVMA 252(6) — periodontal disease and CKD in 169,242 cats',
  url: 'https://everycat.org/cat-health/associations-between-periodontal-disease-and-ckd-in-cats/',
  metric: 'relative risk of chronic kidney disease',
  figure: '~1.5× with stage 3–4 periodontal disease',
}

export const BANFIELD_DENTAL_2024: Citation = {
  label: 'Banfield State of Pet Dental Health, 2024 (>3 million pets)',
  url: 'https://www.banfield.com/about-banfield/newsroom/press-releases/2024/state-of-pet-dental-health',
  metric: 'proportion diagnosed with dental disease',
  figure: '73% of dogs, 64% of cats',
}

export const BRAY_2023: Citation = {
  label: 'Bray et al. 2023, GeroScience 45:645–661 — Dog Aging Project, 11,574 dogs',
  url: 'https://link.springer.com/article/10.1007/s11357-022-00655-8',
  metric: 'odds ratio for clinical canine cognitive dysfunction',
  figure: 'OR 0.53 with higher physical activity — cross-sectional, causality not established',
}

export const HOFFMAN_2013: Citation = {
  label: 'Hoffman, Creevy & Promislow 2013, PLOS ONE 8(4):e61082 — 40,139 dogs',
  url: 'https://journals.plos.org/plosone/article?id=10.1371%2Fjournal.pone.0061082',
  metric: 'mean age at death by reproductive status',
  figure: '9.4 yr sterilised vs 7.9 yr intact; more neoplasia, less trauma and infection',
}

export const HART_2020: Citation = {
  label: 'Hart et al. 2020, Front Vet Sci 7:388 and 7:472 — neuter age and joint disorders',
  url: 'https://www.frontiersin.org/journals/veterinary-science/articles/10.3389/fvets.2020.00388/full',
  metric: 'joint disorder incidence by age at neutering',
  figure: 'risk concentrated in dogs ≥20 kg neutered before 6 months; small breeds unaffected',
}

export const AAHA_CANINE_2019: Citation = {
  label: 'AAHA Canine Life Stage Guidelines, 2019',
  url: 'https://www.aaha.org/resources/life-stage-canine-2019/canine-life-stage-definitions/',
  metric: 'clinical guideline — senior defined as the last 25% of estimated lifespan',
}

export const AAHA_FELINE_2021: Citation = {
  label: 'AAHA/AAFP Feline Life Stage Guidelines, 2021',
  url: 'https://www.aaha.org/resources/2021-aaha-aafp-feline-life-stage-guidelines/feline-life-stage-definitions/',
  metric: 'clinical guideline — kitten <1, young adult 1–6, mature adult 7–10, senior 10+',
}

export const AAHA_SENIOR_2023: Citation = {
  label: 'AAHA Senior Care Guidelines for Dogs and Cats, 2023',
  url: 'https://www.aaha.org/wp-content/uploads/globalassets/02-guidelines/2023-aaha-senior-care-guidelines-for-dogs-and-cats/resources/2023-aaha-senior-care-guidelines-for-dogs-and-cats.pdf',
  metric: 'clinical guideline',
}

export const ACVIM_CARDIO_2020: Citation = {
  label: 'Luis Fuentes et al. 2020, ACVIM consensus on feline cardiomyopathies',
  url: 'https://academic.oup.com/jvim/article/34/3/1062/8448248',
  metric: 'prevalence and predisposed breeds',
  figure: '~15% of the general cat population; up to 29% of older cats',
}

export const TREHIOU_2012: Citation = {
  label: 'Trehiou-Sechi et al. 2012, J Vet Intern Med 26(3) — 344 cats with cardiomyopathy',
  url: 'https://academic.oup.com/jvim/article/26/3/532/8451588',
  metric: 'median age at diagnosis of HCM',
  figure: 'Maine Coon 2.5 yr, Sphynx 3.5 yr, Domestic Shorthair 8.0 yr, Persian 11.0 yr',
}

export const GRANSTROM_2011: Citation = {
  label: 'Granström et al. 2011, J Vet Intern Med 25(4) — 329 British Shorthairs screened',
  url: 'https://academic.oup.com/jvim/article/25/4/866/8451179',
  metric: 'screening prevalence of HCM',
  figure: '8.5% positive; 20.0% of males vs 2.3% of females',
}

export const SEO_2024: Citation = {
  label: 'Seo et al. 2024, Animals 14(18):2629 — 55 Sphynx cats screened',
  url: 'https://www.mdpi.com/2076-2615/14/18/2629',
  metric: 'screening prevalence of HCM',
  figure: '40% (20/55); median age at scan 4.0 yr',
}

export const UCDAVIS_PKD: Citation = {
  label: 'UC Davis Veterinary Genetics Laboratory — feline PKD1',
  url: 'https://vgl.ucdavis.edu/test/pkd1-cat',
  metric: 'estimated breed prevalence',
  figure: 'over 37% of Persians; cysts often present before 12 months',
}

export const UFAW_PKD: Citation = {
  label: 'UFAW — Persian polycystic kidney disease',
  url: 'https://www.ufaw.org.uk/cats/persian-polycystic-kidney-disease',
  metric: 'pooled survey prevalence and age at clinical onset',
  figure: '36–49% affected; mean age at renal failure signs 12.2 yr',
}

export const ONEILL_PERSIAN_2019: Citation = {
  label: "O'Neill et al. 2019, Scientific Reports 9:12952 — 3,235 UK Persians",
  url: 'https://www.nature.com/articles/s41598-019-49317-4',
  metric: 'one-year period prevalence in primary care',
  figure: 'periodontal disease 11.3%; renal disease 23.4% of deaths',
}

export const ONEILL_CATS_2023: Citation = {
  label: "O'Neill et al. 2023, J Feline Med Surg — 18,249 UK cats in primary care",
  url: 'https://journals.sagepub.com/doi/10.1177/1098612X231155016',
  metric: 'one-year period prevalence (primary-care diagnosis rate, not screening)',
  figure: 'periodontal disease 15.2%, obesity 11.6%, hyperthyroidism 1.9%, CKD 1.8%',
}

export const PEREZ_2024: Citation = {
  label: 'Pérez Domínguez et al. 2024, J Feline Med Surg 26(12) — 27,888 cats',
  url: 'https://journals.sagepub.com/doi/10.1177/1098612X241303304',
  metric: 'age at diagnosis of hyperthyroidism',
  figure: 'median 14 yr; 88.8% of cases over 10 yr',
}

export const MARINO_2014: Citation = {
  label: 'Marino et al. 2014, J Feline Med Surg 16(6) — screening study, 86 cats',
  url: 'https://journals.sagepub.com/doi/10.1177/1098612X13511446',
  metric: 'screening prevalence of chronic kidney disease',
  figure: '80.9% of cats aged 15–20',
}

export const WAITE_2025: Citation = {
  label: 'Waite et al. 2025, J Vet Intern Med 39(4) — 1,225,130 UK cats',
  url: 'https://academic.oup.com/jvim/article/39/4/jvim70161/8492752',
  metric: 'age at diagnosis of diabetes mellitus',
  figure: 'mean 11.8 yr; males roughly twice the odds of females',
}

export const UFAW_SIAMESE: Citation = {
  label: 'UFAW — Siamese chronic bronchial disease; Science for Animal Welfare — Siamese amyloidosis',
  url: 'https://www.ufaw.org.uk/cats/siamese-chronic-bronchial-disease',
  metric: 'mean age of onset',
  figure: 'bronchial disease ~4 yr; amyloidosis ~3.5 yr',
}

export const UCDAVIS_PRA: Citation = {
  label: 'UC Davis Veterinary Genetics Laboratory — feline progressive retinal atrophy',
  url: 'https://vgl.ucdavis.edu/test/pra-rdac',
  metric: 'age at onset',
  figure: 'rdAc detectable from ~7 months, most affected cats blind by 3–5 yr',
}

export const APOP_2022: Citation = {
  label: 'Association for Pet Obesity Prevention, 2022 veterinary-assessed prevalence survey',
  url: 'https://www.petobesityprevention.org/2023',
  metric: 'proportion overweight or obese',
  figure: '59% of dogs, 61% of cats',
}
