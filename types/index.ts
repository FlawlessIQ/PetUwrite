export type PetType = "dog" | "cat";

export type PlanId = "essential" | "comprehensive" | "premium";

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

export interface QuoteData {
  petType: PetType | "";
  petName: string;
  breed: string;
  ageYears: string;
  ageMonths: string;
  sex: "" | "male" | "female";
  altered: "" | "yes" | "no";
  plan: PlanId | "";
  firstName: string;
  lastName: string;
  email: string;
  zipCode: string;
  consent: boolean;
}

export interface QuoteErrors {
  petName?: string;
  breed?: string;
  ageYears?: string;
  ageMonths?: string;
  sex?: string;
  altered?: string;
  firstName?: string;
  lastName?: string;
  email?: string;
  zipCode?: string;
  consent?: string;
}
