export type PetType = "dog" | "cat";

export type PlanId = "essential" | "comprehensive" | "premium";
export type YesNoAnswer = "" | "yes" | "no";
export type BodyCondition = "" | "lean" | "ideal" | "overweight" | "not_sure";
export type DeductibleOption = "100" | "250" | "500";
export type ReimbursementOption = "70" | "80" | "90";
export type AnnualLimitOption = "10000" | "20000" | "unlimited";
export type RiderId =
  | "wellness"
  | "examFees"
  | "dentalIllness"
  | "rehab";

export interface NavItem {
  label: string;
  href: string;
}

export interface FaqItem {
  question: string;
  answer: string;
}

export interface Testimonial {
  quote: string;
  name: string;
  detail: string;
  initials: string;
}

export interface Plan {
  id: PlanId;
  title: string;
  price: string;
  deductible: string;
  reimbursement: string;
  highlights: string[];
  recommended?: boolean;
}

export interface Rider {
  id: RiderId;
  title: string;
  price: number;
  body: string;
}

export interface QuoteData {
  quoteCaseId: string;
  petType: PetType | "";
  petName: string;
  breed: string;
  weightLbs: string;
  ageYears: string;
  ageMonths: string;
  sex: "" | "male" | "female";
  altered: "" | "yes" | "no";
  bodyCondition: BodyCondition;
  diagnosedConditions: string[];
  currentSymptoms: YesNoAnswer;
  medication: YesNoAnswer;
  recentSurgery: YesNoAnswer;
  vetRecords: YesNoAnswer;
  plan: PlanId | "";
  deductible: DeductibleOption;
  reimbursement: ReimbursementOption;
  annualLimit: AnnualLimitOption;
  riders: RiderId[];
  conditionDetails: string;
  vetClinicName: string;
  vetClinicPhone: string;
  vetRecordFileNames: string[];
  vetRecordUploads: VetRecordUpload[];
  exclusionAcknowledged: boolean;
  firstName: string;
  lastName: string;
  email: string;
  zipCode: string;
  consent: boolean;
}

export interface VetRecordUpload {
  fileName: string;
  contentType: string;
  sizeBytes: number;
  base64: string;
}

export interface QuoteErrors {
  petName?: string;
  breed?: string;
  weightLbs?: string;
  ageYears?: string;
  ageMonths?: string;
  sex?: string;
  altered?: string;
  bodyCondition?: string;
  diagnosedConditions?: string;
  currentSymptoms?: string;
  medication?: string;
  recentSurgery?: string;
  vetRecords?: string;
  conditionDetails?: string;
  vetClinicName?: string;
  vetClinicPhone?: string;
  vetRecordFileNames?: string;
  exclusionAcknowledged?: string;
  firstName?: string;
  lastName?: string;
  email?: string;
  zipCode?: string;
  consent?: string;
}
