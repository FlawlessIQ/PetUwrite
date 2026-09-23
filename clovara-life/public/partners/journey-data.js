// SOURCE OF TRUTH for the Clovara journey map.
// Edit THIS file to change the live partner map; journey.html renders it.
// Horizons: built | launch | next | sky. Keep entries [name, desc, pillar, horizon, value].

const STAGES=[
 {name:"Before her", age:"The decision", job:"The journey starts before the pet exists. The right match is the biggest health intervention there is — and the family becomes a Clovara family before day one.", moments:[
  ["The Matchmaker","Your home, hours, kids, allergies — matched honestly to breeds and rescues that would thrive with you, with real healthy-years and lifetime-cost expectations.","Plan","sky","growth"],
  ["Ethical Start Network","Partner shelters and health-tested breeders where every pet goes home already carrying a Clovara profile — acquisition at the source, puppy mills starved.","Plan","sky","growth"],
  ["The Countdown","She's coming home in 12 days: puppy-proofing checklist, name shortlist, and a starter box that arrives before she does.","Care","next","love"],
  ["First Visit, Pre-booked","Her first vet appointment is scheduled before her paws touch the floor.","Care","next","habit"]
 ]},
 {name:"The welcome", age:"Day one · week one", job:"Sixty seconds in, the family sees something no pet product has ever shown them — and the whole household joins her circle.", moments:[
  ["The Plan Reveal","Breed, birthday, weight — and her healthy-years outlook, breed risks, and life plan appear. The 'it knows my dog' moment.","Plan","built","growth"],
  ["Arrival Certificate","A beautiful shareable card: her photo, her name, 'her plan begins today.' A keepsake that's also organic acquisition.","Plan","built","growth"],
  ["The Family Circle","Everyone in the household joins her pack with one code — the same plan, the same record, whoever opens the app.","Care","built","habit"],
  ["First-Night Mode","2am, the puppy is crying, and the app is awake with you — calm, specific, hour by hour.","Care","built","love"],
  ["Protect Her Now","Insurance offered at the emotional peak of the reveal — one tap, quote pre-filled from her plan, covered before she has any history.","Protect","built","revenue"]
 ]},
 {name:"Puppyhood", age:"8 weeks – 1 year", job:"The loud, brief chapter where lifelong health and confidence are set — the plan is at its busiest when she is smallest.", moments:[
  ["Socialization Passport","~100 firsts before 16 weeks — umbrellas, skateboards, the vacuum — a stamped, gamified checklist backed by real behavioral evidence.","Care","built","habit"],
  ["Vaccine Autopilot","The whole core series laid out from her birthday, reminded, and recorded as it happens — with your vet still setting the schedule.","Protect","built","habit"],
  ["The Growth Reveal","'She'll be about 62 lbs' — her projected adult self, updated as she grows.","Plan","next","love"],
  ["Two-Minute Trainer","Daily micro-lessons matched to her age and breed temperament.","Care","next","habit"],
  ["Gotcha Day","Her homecoming anniversary, celebrated every year with a shareable card.","Care","built","growth"]
 ]},
 {name:"The daily rhythm", age:"The adult years", job:"Most healthy years are won in the quiet part: small things, done consistently, made effortless — while Clovara watches for what a family can't see.", moments:[
  ["Clovara Score & Streaks","Her wellness score and care streaks — the daily open, the habit loop, the rewards that map to what actually adds healthy years.","Care","built","habit"],
  ["The Nudge","'Activity down 18% this week — unusual for her.' Passive data becomes an act-now moment while it's still a question.","Plan","built","love"],
  ["Morning Briefing","'Slept well. 84° today — walk before 10, pollen high for her allergies.' Her day, not a generic tip.","Care","next","habit"],
  ["Food Scanner","Point the camera at any kibble or treat in any store: 'good for her?' — judged against her weight, allergies and conditions.","Care","next","habit"],
  ["Environmental Guardian","Breed-aware heat alerts, toxic-algae and mushroom-season warnings by location.","Plan","next","love"],
  ["The Shelf That Grows","Products picked from her plan with a plain-words 'why' — teething chews then, joint support now, nothing that doesn't serve her today.","Care","built","revenue"],
  ["The CloTag","Clovara-branded tracker (partner hardware) in the membership from day one — activity, sleep and vitals become her fitness score, the always-on signal behind the nudges.","Plan","launch","data"],
  ["The Fitness Score","Her daily score from the CloTag — the habit loop's engine and, in aggregate, the only dataset linking continuous activity to claims outcomes.","Plan","launch","data"],
  ["Walk Intelligence","Routes scored for her needs — shade for flat faces, soft ground for old hips, sniff-rich paths for enrichment.","Care","sky","habit"],
  ["Smart-Home Senses","Feeder, door camera and litter sensors — separation-anxiety patterns, and early kidney flags for cats from litter habits.","Plan","sky","data"],
  ["The Annual Re-Projection","Every birthday her plan is re-drawn from the year she actually lived — what changed, what held, and what it moved. The product's heartbeat.","Plan","built","love"]
 ]},
 {name:"Life happens", age:"The in-between moments", job:"Real life keeps changing around the pet — sitters, travel, new babies, new houses, second dogs. Clovara flexes around the family.", moments:[
  ["Sitter Mode","One expiring link with everything a sitter, boarder or groomer needs — meds, quirks, vet, emergency contacts.","Care","built","love"],
  ["Lost-Pet Alert + CloTag Scan","Anyone who finds her scans her tag and reaches you instantly; every Clovara household within two miles gets the alert.","Care","next","love"],
  ["The DNA Reveal","A cheek swab: breed-mix reveal for the rescue (the most shareable moment in pet tech) and health markers that tune her plan for life.","Plan","next","data"],
  ["Pet Passport","Airline rules, country requirements and health certificates, handled — travel without the paperwork panic.","Care","sky","love"],
  ["New-Baby Mode","A guided program for the biggest disruption in a pet's life — introductions, routines, warning signs.","Care","sky","love"],
  ["Moving-House Mode","New vet found, records transferred, local risks re-learned, settling-in plan for her.","Care","sky","love"],
  ["The Second-Pet Matchmaker","Thinking about a friend for her? Matched to her temperament, age and the household she already runs.","Plan","sky","growth"],
  ["The Pack Dashboard","Every pet in the family on one screen — multi-pet households are the most valuable members.","Plan","next","revenue"],
  ["Points That Give Back","Redeem rewards as shelter donations in her name — loyalty that feels like love.","Care","next","love"],
  ["The Research Pack","Opt-in, consented member data powering published longevity studies — her data adds healthy years for every dog.","Plan","sky","data"]
 ]},
 {name:"The worry moments", age:"Any Tuesday, 11pm", job:"Every owner knows the 11pm fear. Clovara answers with her history in hand — informing and routing to vets, never guessing, never diagnosing.", moments:[
  ["The Companion That Remembers","'She's limping after walks' → recalls the hip note from 2024, says what to watch, books a video vet with her history summary prepared.","Care","built","love"],
  ["'She Ate a Grape'","Instant risk banding by her weight, one tap to the poison line, and the plain instruction not to wait for signs.","Care","built","love"],
  ["The Lump Diary","Photograph the weird thing; compare it against last month's photo of the same thing. Watch or go — with receipts.","Care","next","data"],
  ["Gait Check","Slow-motion video of her walk, compared to her own baseline from years ago — catching the limp before the limp.","Plan","sky","data"],
  ["Second Opinion","Upload a diagnosis or a $6,000 estimate: plain-language explanation, questions to ask, fair local cost range.","Care","next","love"],
  ["Vet Visit Recorder","Record the consult (with consent) — a plain-words recap, the care tasks extracted, nothing forgotten in the car park.","Care","sky","love"]
 ]},
 {name:"When it's serious", age:"The bad day", job:"The moment the whole promise exists for. The family's job is to be with her — Clovara's job is everything else.", moments:[
  ["Claim in Hours","Photo of the invoice. Approved in hours, paid same day. The anti-horror-story.","Protect","built","love"],
  ["Direct-Pay Network","The blue-sky version: no claim at all. The vet bills Clovara; the family just takes her home.","Protect","sky","love"],
  ["Surgery Companion","Pre-op explained in plain words, then recovery mode: daily check-ins, incision photo checks, activity targets paused.","Care","next","love"],
  ["Meds Autopilot","Reminders, auto-refills, interaction warnings — adherence without the sticky notes.","Care","next","revenue"],
  ["The Re-Plan","After the event, her whole plan quietly reshapes — food, activity, screening — around who she is now.","Plan","next","love"],
  ["Renewal, Explained","At renewal: why her premium is what it is — and what her care this year kept it from being. Radical transparency as retention.","Protect","launch","love"],
  ["Claims, Corroborated","Her CloTag timeline substantiates the claim automatically — the sudden change Tuesday, the vet Wednesday, approved in minutes. Data used for her, never against her.","Protect","next","love"],
  ["The Loss-Control Tag","In value-added-services states, policyholders get the CloTag free — a loss-prevention device by law, like a leak sensor from a home insurer.","Protect","next","revenue"],
  ["The Data Covenant","A public promise, from day one: tracker and companion data work for your pet and aggregate science — never against an individual claim or premium.","Protect","built","love"],
  ["Earned Rates","The endgame: years of fitness-score-to-claims data become a filed, state-approved rating program where healthy engagement genuinely earns the price.","Protect","sky","revenue"]
 ]},
 {name:"The senior years", age:"The last 25%", job:"Where pet-centric is proven. The app ages with her — comfort, dignity, and catching the small declines early.", moments:[
  ["The Senior Shift","Her care path and shelf quietly change — senior screening, ramps, orthopedic beds — computed from her breed's own timeline.","Plan","built","revenue"],
  ["Mobility Monitor","A monthly minute of video becomes a mobility score and a validated pain check-in.","Plan","next","data"],
  ["Bloodwork, Trended","Kidney and thyroid panels charted across years — the lines you want to stay flat, watched.","Plan","next","data"],
  ["The Quality-of-Life Compass","Vet-partnered, validated QoL tracking for the final stretch — clarity and peace for the hardest decision in pet ownership.","Care","sky","love"]
 ]},
 {name:"Remember", age:"Goodbye, and after", job:"Nobody in this industry does grief well. Handled with grace, this chapter earns loyalty that lasts across every pet a family will ever love.", moments:[
  ["Dignity Coverage","End-of-life costs handled with zero friction — no forms on the worst day.","Protect","next","love"],
  ["Her Story","Her whole timeline — photos, milestones, the walks, the years — printed as a book.","Care","next","revenue"],
  ["The Memorial","Her profile becomes a remembrance page; a shelter donation made in her name.","Care","next","love"],
  ["When You're Ready","Months later, gently: the family's next chapter — carrying everything Clovara learned about how they love.","Plan","next","growth"]
 ]}
];

const HZ={built:"Built",launch:"Launch",next:"Next",sky:"Blue sky"};
