class BreedCatalog {
  // Many insurers bucket mixed-breed dogs by expected adult size to improve
  // pricing accuracy when the exact breed is unknown.
  static const List<String> dogMixedBuckets = [
    'Mixed - Small (0–25 lbs)',
    'Mixed - Medium (25–55 lbs)',
    'Mixed - Large (55–90 lbs)',
    'Mixed - Giant (90+ lbs)',
    'Mixed Breed',
    'Unknown / Not sure',
  ];

  static const List<String> dogBreeds = [
    // Mixed/unknown (keep near top)
    ...dogMixedBuckets,
    'Labrador Retriever',
    'Golden Retriever',
    'German Shepherd',
    'French Bulldog',
    'Bulldog',
    'Poodle',
    'Beagle',
    'Rottweiler',
    'Dachshund',
    'German Shorthaired Pointer',
    'Pembroke Welsh Corgi',
    'Australian Shepherd',
    'Yorkshire Terrier',
    'Boxer',
    'Siberian Husky',
    'Cavalier King Charles Spaniel',
    'Great Dane',
    'Doberman Pinscher',
    'Miniature Schnauzer',
    'Shih Tzu',
    'Boston Terrier',
    'Bernese Mountain Dog',
    'Pomeranian',
    'Havanese',
    'Shetland Sheepdog',
    'Brittany',
    'English Springer Spaniel',
    'Cocker Spaniel',
    'Border Collie',
    'Basset Hound',
    'Maltese',
    'Weimaraner',
    'Chihuahua',
    'Bichon Frise',
    'Akita',
    'Bull Terrier',
    'Staffordshire Bull Terrier',
    'Pit Bull',
    'American Staffordshire Terrier',
    'Cane Corso',
    'Shiba Inu',
    'Vizsla',
    'Collie',
    'Newfoundland',
    'Saint Bernard',
    'Mastiff',
    'Irish Wolfhound',
    'Whippet',
    'Greyhound',
    'Pug',
    'Borzoi',
    'Samoyed',
    'Alaskan Malamute',
    'Jack Russell Terrier',
    'West Highland White Terrier',
    'Scottish Terrier',
    'Airedale Terrier',
    'Australian Cattle Dog',
    'Catahoula Leopard Dog',
    'Blenheim Spaniel',
    'Chinese Crested',
    'Belgian Malinois',
    'Great Pyrenees',
    'Papillon',
    'Pekingese',
    'Lhasa Apso',
    'Basenji',
    'Shar Pei',
    'Bolognese',
    'Italian Greyhound',
    'Coton de Tulear',
    'Toy Poodle',
    'Miniature Poodle',
    'Standard Poodle',
    'Cockapoo',
    'Goldendoodle',
    'Labradoodle',
    'Cavapoo',
  ];

  static const List<String> catBreeds = [
    'Mixed Breed',
    'Unknown / Not sure',
    'Domestic Shorthair',
    'Domestic Longhair',
    'Maine Coon',
    'Ragdoll',
    'British Shorthair',
    'Persian',
    'Siamese',
    'Bengal',
    'Sphynx',
    'Abyssinian',
    'Russian Blue',
    'Scottish Fold',
    'American Shorthair',
    'Birman',
    'Norwegian Forest Cat',
    'Devon Rex',
    'Cornish Rex',
    'Oriental Shorthair',
    'Himalayan',
    'Manx',
    'Turkish Angora',
    'Turkish Van',
    'Savannah',
    'Tonkinese',
    'Bombay',
    'Ragamuffin',
    'Balinese',
    'Chartreux',
    'Exotic Shorthair',
    'American Curl',
  ];

  static List<String> breedsForSpecies(String? species) {
    final s = (species ?? '').toLowerCase().trim();
    if (s == 'cat') return catBreeds;
    return dogBreeds;
  }

  static List<String> mixedBucketsForSpecies(String? species) {
    final s = (species ?? '').toLowerCase().trim();
    if (s == 'cat') {
      return const [
        'Mixed Breed',
        'Unknown / Not sure',
      ];
    }
    return dogMixedBuckets;
  }

  static List<String> popularBreedsForSpecies(String? species) {
    final s = (species ?? '').toLowerCase().trim();
    if (s == 'cat') {
      return const [
        'Domestic Shorthair',
        'Domestic Longhair',
        'Maine Coon',
        'Ragdoll',
        'Siamese',
        'Persian',
        'Bengal',
        'Mixed Breed',
        'Unknown / Not sure',
      ];
    }

    return const [
      'Mixed - Small (0–25 lbs)',
      'Mixed - Medium (25–55 lbs)',
      'Mixed - Large (55–90 lbs)',
      'Mixed Breed',
      'Labrador Retriever',
      'Golden Retriever',
      'German Shepherd',
      'French Bulldog',
      'Poodle',
      'Beagle',
      'Chihuahua',
    ];
  }
}
