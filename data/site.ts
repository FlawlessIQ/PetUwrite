import type { FaqItem, NavItem, Plan, Testimonial } from "@/types";

export const navItems: NavItem[] = [
  { label: "Coverage", href: "/coverage" },
  { label: "How it works", href: "/how-it-works" },
  { label: "Claims", href: "/#claims" },
  { label: "About", href: "/about" }
];

export const trustStats = [
  { value: "4.8★", label: "App Store rating" },
  { value: "2 days", label: "Average claim time" },
  { value: "$0", label: "Hidden fees" },
  { value: "24/7", label: "Vet helpline access" },
  { value: "90%", label: "Max reimbursement" }
];

export const howItWorksSteps = [
  {
    title: "Tell us about your pet",
    body: "Breed, age, and a few health details. This takes about 90 seconds."
  },
  {
    title: "Pick your plan",
    body: "Choose deductible and reimbursement rate. See the exact monthly price, no estimates."
  },
  {
    title: "Coverage starts today",
    body: "Your policy is active immediately. Documents arrive in your inbox within minutes."
  },
  {
    title: "File claims from your phone",
    body: "Upload a photo of your vet invoice. We pay within 2 business days."
  }
];

export const testimonials: Testimonial[] = [
  {
    quote:
      "My golden had emergency surgery. $6,800 bill. Clovara paid $6,120 within 48 hours. I actually cried with relief.",
    name: "Sarah R.",
    detail: "Golden Retriever parent · Austin, TX",
    initials: "SR"
  },
  {
    quote:
      "Filing a claim is literally just taking a photo. I've been reimbursed three times and never had to speak to anyone.",
    name: "Marcus K.",
    detail: "French Bulldog parent · Chicago, IL",
    initials: "MK"
  },
  {
    quote:
      "I switched from my old carrier. The transparency is night and day. I actually understand what I'm paying for now.",
    name: "Jamie L.",
    detail: "Siamese cat parent · Portland, OR",
    initials: "JL"
  }
];

export const faqs: FaqItem[] = [
  {
    question: "What does Clovara actually cover?",
    answer:
      "Accidents, illnesses, surgery, emergency care, hospitalisation, and specialist visits. Optional wellness add-on covers checkups, vaccines, and flea prevention."
  },
  {
    question: "Are there breed restrictions?",
    answer:
      "No. We cover all breeds of dogs and cats including those excluded by legacy insurers."
  },
  {
    question: "How fast are claims paid?",
    answer:
      "Our average is 2 business days from when we receive your invoice. Complex claims may take up to 5 days."
  },
  {
    question: "Is there a waiting period?",
    answer:
      "14-day waiting period for illness. Accidents are covered from day 1."
  },
  {
    question: "What counts as a pre-existing condition?",
    answer:
      "Any condition your pet showed signs of before your policy start date. We assess this fairly and explain every decision."
  },
  {
    question: "Can I use any vet?",
    answer:
      "Yes. Clovara works with any licensed veterinarian in the US - no network restrictions."
  },
  {
    question: "What deductible options are available?",
    answer:
      "$100, $250, or $500 annual deductible. Higher deductible = lower monthly premium."
  },
  {
    question: "Can I cancel any time?",
    answer:
      "Yes. Cancel with 30 days notice, no cancellation fee. We'll refund any unused premium."
  }
];

export const plans: Plan[] = [
  {
    id: "essential",
    title: "Essential",
    price: "$XX/mo",
    deductible: "$500/yr",
    reimbursement: "70%",
    highlights: ["Accidents & illness", "Emergency care", "Specialist visits"]
  },
  {
    id: "comprehensive",
    title: "Comprehensive",
    price: "$XX/mo",
    deductible: "$250/yr",
    reimbursement: "80%",
    highlights: [
      "Everything in Essential",
      "Prescription medications",
      "Cancer treatment"
    ],
    recommended: true
  },
  {
    id: "premium",
    title: "Premium",
    price: "$XX/mo",
    deductible: "$100/yr",
    reimbursement: "90%",
    highlights: [
      "Everything in Comprehensive",
      "Wellness add-on included",
      "Priority claims processing"
    ]
  }
];

export const dogBreeds = [
  "Labrador",
  "Golden Retriever",
  "French Bulldog",
  "German Shepherd",
  "Bulldog",
  "Poodle",
  "Beagle",
  "Rottweiler",
  "Yorkshire Terrier",
  "Dachshund",
  "Boxer",
  "Siberian Husky",
  "Great Dane",
  "Doberman",
  "Australian Shepherd",
  "Shih Tzu",
  "Border Collie",
  "Cavalier King Charles",
  "Maltese",
  "Boston Terrier"
];

export const catBreeds = [
  "Domestic Shorthair",
  "Maine Coon",
  "Siamese",
  "Ragdoll",
  "Persian",
  "Bengal",
  "British Shorthair",
  "Sphynx",
  "Scottish Fold",
  "Russian Blue"
];
