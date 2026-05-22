import type { FaqItem, NavItem, Plan, Rider, Testimonial } from "@/types";

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

export const expandedHowItWorksSteps = [
  {
    number: "01",
    title: "Tell us about your pet",
    paragraphs: [
      "Start with the basics: your pet's breed, age, and a few health details. The questions are written in plain English, so you never need to decode insurance language.",
      "Most families finish this part in about 90 seconds. If you do not know an answer, we help you keep moving without making the quote feel fragile."
    ],
    mockupTitle: "Pet profile",
    mockupRows: ["Biscuit", "Golden Retriever", "3 years old"]
  },
  {
    number: "02",
    title: "Pick your plan",
    paragraphs: [
      "Choose a deductible and reimbursement level that fits your monthly budget. Each plan shows what is included before you move forward.",
      "No estimate games, no fine-print maze. You see the price and the tradeoffs clearly enough to make a calm decision."
    ],
    mockupTitle: "Plan options",
    mockupRows: ["Essential", "Comprehensive", "Premium"]
  },
  {
    number: "03",
    title: "Coverage starts today",
    paragraphs: [
      "Once you accept, your policy documents arrive by email within minutes. You can save them, share them, or pull them up when your vet asks.",
      "Accidents are covered from day 1. Illness has a short waiting period, and we explain that up front instead of hiding it later."
    ],
    mockupTitle: "Policy active",
    mockupRows: [
      "Documents sent",
      "Accidents day 1",
      "Illness after waiting period"
    ]
  },
  {
    number: "04",
    title: "File claims from your phone",
    paragraphs: [
      "When something happens, take a photo of the vet invoice and upload it. You can track the claim status without calling a support line.",
      "Most claims are paid in 2 business days. If a claim needs more detail, we tell you exactly what is missing and why."
    ],
    mockupTitle: "Claim tracker",
    mockupRows: ["Invoice uploaded", "Checking", "Paid"]
  }
];

export const coverageRows = [
  {
    feature: "Accidents",
    essential: "Included",
    comprehensive: "Included",
    premium: "Included"
  },
  {
    feature: "Illness",
    essential: "Included",
    comprehensive: "Included",
    premium: "Included"
  },
  {
    feature: "Emergency care",
    essential: "Included",
    comprehensive: "Included",
    premium: "Included"
  },
  {
    feature: "Specialist visits",
    essential: "Included",
    comprehensive: "Included",
    premium: "Included"
  },
  {
    feature: "Prescription medications",
    essential: "Limited",
    comprehensive: "Included",
    premium: "Included"
  },
  {
    feature: "Cancer treatment",
    essential: "Limited",
    comprehensive: "Included",
    premium: "Included"
  },
  {
    feature: "Wellness care",
    essential: "Add-on",
    comprehensive: "Add-on",
    premium: "Included"
  },
  {
    feature: "Priority claims processing",
    essential: "Standard",
    comprehensive: "Standard",
    premium: "Included"
  }
];

export const exclusions = [
  {
    title: "Pre-existing conditions",
    body: "A condition your pet showed signs of before coverage started. We explain the decision clearly if this applies."
  },
  {
    title: "Cosmetic procedures",
    body: "Procedures done for appearance rather than health, like tail docking or ear cropping, are not covered."
  },
  {
    title: "Elective surgeries",
    body: "Optional procedures that are not medically necessary are not included in accident and illness coverage."
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
    question: "What does Clovara cover?",
    answer:
      "Clovara plan options are built around accident and illness coverage, including emergency care and specialist visits. Higher tiers can include prescription medications, cancer treatment, wellness care, and priority claims processing."
  },
  {
    question: "Do you cover both dogs and cats?",
    answer:
      "Yes. The quote flow currently supports dogs and cats, with breed-specific questions so the plan can reflect the pet you actually have."
  },
  {
    question: "Can I use any vet?",
    answer:
      "The product is designed to work with licensed veterinarians in the US, without a narrow in-network vet list. Final availability and terms may vary by state."
  },
  {
    question: "What deductible and reimbursement options are shown?",
    answer:
      "The current quote flow shows $500, $250, and $100 annual deductible options across Essential, Comprehensive, and Premium plans, with reimbursement levels from 70% to 90%."
  },
  {
    question: "How do claims work?",
    answer:
      "Claims are designed to be filed digitally by uploading a vet invoice. Straightforward claims can move quickly, while more complex claims may ask for extra records before the automated decision can finish."
  },
  {
    question: "Is there a waiting period?",
    answer:
      "The current product copy shows accidents starting on day 1 and a 14-day waiting period for illness. Final policy documents should always be reviewed before purchase."
  },
  {
    question: "What counts as a pre-existing condition?",
    answer:
      "A pre-existing condition is generally a health issue your pet showed signs of before the policy start date. Any decision should be explained clearly in plain English."
  },
  {
    question: "Can I cancel any time?",
    answer:
      "The customer experience should make cancellation simple. Specific notice periods, refunds, and state rules should be confirmed in the final policy terms before launch."
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
  "Mixed - Small (0-25 lbs)",
  "Mixed - Medium (25-55 lbs)",
  "Mixed - Large (55-90 lbs)",
  "Mixed - Giant (90+ lbs)",
  "Mixed Breed",
  "Unknown / Not sure",
  "Labrador Retriever",
  "Golden Retriever",
  "German Shepherd",
  "French Bulldog",
  "Bulldog",
  "Poodle",
  "Beagle",
  "Rottweiler",
  "Dachshund",
  "German Shorthaired Pointer",
  "Pembroke Welsh Corgi",
  "Australian Shepherd",
  "Yorkshire Terrier",
  "Boxer",
  "Siberian Husky",
  "Cavalier King Charles Spaniel",
  "Great Dane",
  "Doberman Pinscher",
  "Miniature Schnauzer",
  "Shih Tzu",
  "Boston Terrier",
  "Bernese Mountain Dog",
  "Pomeranian",
  "Havanese",
  "Shetland Sheepdog",
  "Brittany",
  "English Springer Spaniel",
  "Cocker Spaniel",
  "Border Collie",
  "Basset Hound",
  "Maltese",
  "Weimaraner",
  "Chihuahua",
  "Bichon Frise",
  "Akita",
  "Bull Terrier",
  "Staffordshire Bull Terrier",
  "Pit Bull",
  "American Staffordshire Terrier",
  "Cane Corso",
  "Shiba Inu",
  "Vizsla",
  "Collie",
  "Newfoundland",
  "Saint Bernard",
  "Mastiff",
  "Irish Wolfhound",
  "Whippet",
  "Greyhound",
  "Pug",
  "Borzoi",
  "Samoyed",
  "Alaskan Malamute",
  "Jack Russell Terrier",
  "West Highland White Terrier",
  "Scottish Terrier",
  "Airedale Terrier",
  "Australian Cattle Dog",
  "Catahoula Leopard Dog",
  "Chinese Crested",
  "Belgian Malinois",
  "Great Pyrenees",
  "Papillon",
  "Pekingese",
  "Lhasa Apso",
  "Basenji",
  "Shar Pei",
  "Bolognese",
  "Italian Greyhound",
  "Coton de Tulear",
  "Toy Poodle",
  "Miniature Poodle",
  "Standard Poodle",
  "Cockapoo",
  "Goldendoodle",
  "Labradoodle",
  "Cavapoo",
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
  "Mixed Breed",
  "Unknown / Not sure",
  "Domestic Shorthair",
  "Domestic Longhair",
  "Maine Coon",
  "Ragdoll",
  "British Shorthair",
  "Persian",
  "Siamese",
  "Bengal",
  "Sphynx",
  "Abyssinian",
  "Russian Blue",
  "Scottish Fold",
  "American Shorthair",
  "Birman",
  "Norwegian Forest Cat",
  "Devon Rex",
  "Cornish Rex",
  "Oriental Shorthair",
  "Himalayan",
  "Manx",
  "Turkish Angora",
  "Turkish Van",
  "Savannah",
  "Tonkinese",
  "Bombay",
  "Ragamuffin",
  "Balinese",
  "Chartreux",
  "Exotic Shorthair",
  "American Curl"
];

export const quoteRiders: Rider[] = [
  {
    id: "wellness",
    title: "Wellness care",
    price: 18,
    body: "Routine exams, vaccines, flea prevention, and annual checkups."
  },
  {
    id: "examFees",
    title: "Vet exam fees",
    price: 7,
    body: "Reimburses eligible exam fees tied to covered accidents or illness."
  },
  {
    id: "dentalIllness",
    title: "Dental illness",
    price: 9,
    body: "Coverage for eligible non-routine dental illness and treatment."
  },
  {
    id: "rehab",
    title: "Rehab and recovery",
    price: 11,
    body: "Physical therapy, acupuncture, and recovery support when covered."
  }
];
