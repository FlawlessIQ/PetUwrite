# The copy that carries judgement

BACKLOG **P2**. Extracted 2026-09-26 from the live code — the words below are what
renders, not a paraphrase. **126 items**, out of about 2,920 strings of customer copy:
every refusal, the escalation ladder and the poison flow, the goodbye flow, the
senior suite, the disclosures and the Data Covenant. Everything else is
navigation, labels and explanation, and does not decide anything.

**How to use it.** Read a section in one sitting. In *Verdict*, write **keep**,
**change** (with the change, or "rewrite") or **discuss**. Nothing here has been
read by anyone but Claude Code, except where DESIGN.md or DECISIONS records a
decision of yours. Items marked *unread* were written in the last day.

**Who else reads it.** §1–§3 go to the vet reviewer (A1/R1). §8–§9 go to counsel
(A2). §4, §6 and §7 are the six refusals P4 asks you to ratify or overturn.

Placeholders: the pet is **Bruno**, a Labrador with hip dysplasia on file, aged
10½ — so every line reads as an owner would see it.

## 1 · The escalation ladder — "Something is wrong"

The most important screen in the product (UAT A5.2). Whether it escalates is decided by the 17 signs below; what it says when it does not is the dangerous half. **Also for the vet reviewer (A1).**

| id | Where | Exact words | Why it is judgement | Verdict |
|---|---|---|---|---|
| J1 | Result, a sign matched — headline | Stop and ring a vet now. | The only instruction a frightened person may read | |
| J2 | Result, a sign matched — body | From what you have written, this is not something to watch and see. Ring your own practice — out of hours they will have a number that is answered — or the nearest emergency vet. If you are not sure, ring anyway. Nobody minds the call that turned out to be nothing. |  | |
| J3 | Result, nothing matched — headline | We have not spotted anything on our urgent list. | Must never read as reassurance | |
| J4 | Result, nothing matched — body | That is a statement about our list, not about your pet. We match a short set of signs that always need a vet immediately, and plenty of serious things are not on it. If you are worried, ring your practice — you know them and we do not. | The refusal to reassure | |
| J5 | Footer | Still being reviewed by a vet: this list is written to send you to a vet more often than strictly necessary rather than less. | Says the list is unreviewed, to the owner | |
| J6 | Red flag | **Collapsed, or will not get up** — An animal that cannot stand needs to be seen now, whatever the cause. | Escalates straight to "ring a vet now" | |
| J7 | Red flag | **Struggling to breathe** — Breathing trouble is the one thing that does not wait, and it can look mild minutes before it does not. | Escalates straight to "ring a vet now" | |
| J8 | Red flag (c, a, t only) | **Open-mouth breathing or panting** — A panting cat is not a hot cat. Cats almost never pant, and one that is doing it needs to be seen now. | Escalates straight to "ring a vet now" | |
| J9 | Red flag | **A seizure, or fitting** — A first seizure, a long one, or several close together all need a vet the same day. | Escalates straight to "ring a vet now" | |
| J10 | Red flag (c, a, t only) | **Straining in the litter tray** — In a male cat this can be a blockage, and it becomes life-threatening in hours rather than days. It is the single most time-critical thing on this list. | Escalates straight to "ring a vet now" | |
| J11 | Red flag (d, o, g only) | **Swollen belly, retching with nothing coming up** — A swollen abdomen with unproductive retching is an emergency in any dog and especially a deep-chested one. Hours matter. | Escalates straight to "ring a vet now" | |
| J12 | Red flag | **Bleeding that will not stop** — Press on it with something clean and go. Judging how much blood is too much is not something to do at home. | Escalates straight to "ring a vet now" | |
| J13 | Red flag | **Hit, fallen, or crushed** — Serious internal injury is common after impact and often shows nothing at all at first. | Escalates straight to "ring a vet now" | |
| J14 | Red flag | **Pale, white or tacky gums** — Gum colour is one of the few things an owner can check that genuinely changes the urgency. | Escalates straight to "ring a vet now" | |
| J15 | Red flag | **Ate something they should not have** — For most of what is dangerous, treatment works best before an animal looks unwell. | Escalates straight to "ring a vet now" | |
| J16 | Red flag | **Overheated** — Heatstroke does damage that continues after the animal looks cooler. | Escalates straight to "ring a vet now" | |
| J17 | Red flag | **Sudden swelling of the face, or hives** — A reaction that is swelling a face can go on to affect breathing. | Escalates straight to "ring a vet now" | |
| J18 | Red flag | **Trouble giving birth** — Time between puppies or kittens is the thing that matters, and it is easy to leave too long. | Escalates straight to "ring a vet now" | |
| J19 | Red flag | **A painful or injured eye** — Eyes do not wait. A day can be the difference between keeping and losing one. | Escalates straight to "ring a vet now" | |
| J20 | Red flag | **In obvious pain** — An animal showing pain that plainly has usually been hiding it for a while. | Escalates straight to "ring a vet now" | |
| J21 | Red flag (c, a, t only) | **Not eating** — A cat that stops eating for a couple of days can develop a serious liver problem from the fasting itself, whatever started it. | Escalates straight to "ring a vet now" | |
| J22 | Red flag | **Repeated vomiting or diarrhoea** — Dehydration happens quickly in a small animal, and blood changes the urgency. | Escalates straight to "ring a vet now" | |

## 2 · "Ate something"

The poison flow (SPEC §6.5). Order is the design: numbers first, lookup last. 16 substances; each one's urgency is decided in code from the lines below. **Also for the vet reviewer (A1).**

| id | Where | Exact words | Why it is judgement | Verdict |
|---|---|---|---|---|
| J23 | Top of screen | Ring your vet or a poison line now. Do not wait for signs — for most of what is on this list, treatment works best before an animal looks unwell. | First thing read | |
| J24 | Top of screen | Do not try to make them sick. It is the wrong thing for some of what is on this list and it causes its own injuries — whether to do it at all is a decision for the person on the phone. | Refuses the most common home remedy | |
| J25 | Top of screen | Take the packet, the wrapper or a photograph of the plant with you. What it was matters more than how much, and it is the first thing you will be asked. |  | |
| J26 | Footer | This is information, not veterinary advice, and it is not a substitute for ringing someone. If you are not sure, ring. Nobody minds the call that turned out to be nothing. |  | |
| J27 | No lookup available | We cannot look up your nearest open emergency vet yet. Search for "emergency vet near me", or ring a poison line — they will tell you where to go. |  | |
| J28 | Substance — Grapes, raisins, sultanas or currants (dog; always "ring now") | Why: The reaction is idiosyncratic — some dogs have gone into kidney failure after a handful, and others have eaten a punnet with nothing at all. Because nobody can tell which dog they have, there is no amount treated as safe. · Signs: Vomiting, then being quiet or off food over the following day or two. |  | |
| J29 | Substance — Xylitol or birch sugar (dog, cat; always "ring now") | Why: It acts at very small quantities and very quickly — a few pieces of sugar-free gum is enough for a small dog. It is increasingly in peanut butter, protein bars and some medicines. · Signs: Wobbliness, weakness or collapse, sometimes within half an hour. |  | |
| J30 | Substance — Lily — any part, including pollen (cat; always "ring now") | Why: True lilies and daylilies cause kidney failure in cats. Chewing a leaf, drinking the vase water, or grooming pollen off their own coat is enough. Treatment works best before signs appear, which is why this is a now call rather than a wait-and-see. · Signs: Drooling, vomiting, hiding, or not drinking. Often nothing at all at first. |  | |
| J31 | Substance — Antifreeze or screenwash (dog, cat; always "ring now") | Why: Very small amounts cause kidney failure, it tastes sweet so animals drink it willingly, and the window in which treatment works is measured in hours. · Signs: Appearing drunk, then seeming to recover, then becoming very unwell a day or two later. |  | |
| J32 | Substance — Rat or mouse poison (dog, cat; always "ring now") | Why: Different poisons do entirely different things and the treatment differs completely, so the packet matters more than the amount. Take a photograph of it before you leave the house. · Signs: Often nothing for days, which is the danger. Later: bruising, bleeding, weakness, or fits. |  | |
| J33 | Substance — Human painkillers — ibuprofen, paracetamol, aspirin, naproxen (dog, cat; always "ring now") | Why: Doses that are ordinary for a person damage the stomach, the kidneys or the liver in a dog, and cats cannot process paracetamol at all — a single tablet can kill a cat. · Signs: Vomiting, being off food, dark or tarry stools. In cats, brown gums and laboured breathing. |  | |
| J34 | Substance — Cannabis or edibles (dog, cat; always "ring now") | Why: Edibles are the real problem, because they usually also contain chocolate or xylitol. Nobody is in trouble for saying what was eaten, and a vet needs to know to treat it properly. · Signs: Wobbling, dribbling urine, startling at sounds, very dilated pupils. |  | |
| J35 | Substance — Sago palm (dog, cat; always "ring now") | Why: Every part is toxic and the seeds most of all. It causes liver failure and it is one of the least survivable things on this list if it waits. · Signs: Vomiting, then jaundice a day or two later. |  | |
| J36 | Substance — Chocolate (dog, cat; banded by amount) | Why: The problem is theobromine, and how much is in it varies enormously — the same weight of baking chocolate carries roughly seven times what milk chocolate does. · Signs: Restlessness, a racing heart, vomiting, tremors. |  | |
| J37 | Substance — Onion, garlic, leek or chive (dog, cat; banded by amount) | Why: They damage red blood cells, and cats are considerably more sensitive than dogs. Powders and gravy granules are far more concentrated than the vegetable. · Signs: Often nothing for a few days, then pale gums, tiredness, or orange-brown urine. |  | |
| J38 | Substance — Macadamia nuts (dog; banded by amount) | Why: Dogs get weak in the back legs and feverish. It is rarely fatal and it is alarming to watch. · Signs: Wobbliness or weakness in the back legs, tremors, a temperature. |  | |
| J39 | Substance — Coffee, tea or energy drinks (dog, cat; banded by amount) | Why: It does much what chocolate does, and grounds and tablets are far more concentrated than a cup of anything. · Signs: Restlessness, a racing heart, vomiting, tremors. |  | |
| J40 | Substance — Raw bread dough (dog, cat; always "ring now") | Why: It keeps rising in a warm stomach and the yeast produces alcohol while it does. Both halves are dangerous and the swelling can be a surgical problem. · Signs: A swollen, painful belly, retching without bringing anything up, appearing drunk. |  | |
| J41 | Substance — Alcohol (dog, cat; always "ring now") | Why: Animals are far smaller than us and far more sensitive, and it drops their blood sugar and their temperature as well as intoxicating them. · Signs: Wobbliness, vomiting, cold, drowsy, slow breathing. |  | |
| J42 | Substance — Vitamin D supplements (dog, cat; always "ring now") | Why: The margin between a human dose and a toxic one for an animal is very small, and it causes kidney damage that is hard to reverse once it is under way. · Signs: Drinking and urinating much more than usual, vomiting, being off food. |  | |
| J43 | Substance — A battery, especially a button cell (dog, cat; always "ring now") | Why: A swallowed button cell can burn through tissue within hours. This is one of the few things on this list where the clock genuinely matters that much. · Signs: Drooling, retching, refusing food, pawing at the mouth. |  | |

## 3 · First Nights

The first 72 hours with a new puppy or kitten, written for 2am.

| id | Where | Exact words | Why it is judgement | Verdict |
|---|---|---|---|---|
| J44 | Always visible | Call a vet now, at any hour, for: repeated vomiting or diarrhoea, a refusal to eat or drink for more than about twelve hours, gums that are pale or tacky, laboured breathing, collapse, a seizure, or a fall or crush injury. None of these are settling problems. | When to stop reading and ring | |
| J45 | Footer | This is information, not veterinary advice, and it never replaces your own vet. If something feels wrong to you, that is reason enough to call. |  | |

## 4 · The companion's refusals

What the companion says instead of answering. Each is a choice not to diagnose, not to guess, or not to pretend a vet is available (invariant 4). **P4 asks you to ratify or overturn these.**

| id | Where | Exact words | Why it is judgement | Verdict |
|---|---|---|---|---|
| J46 | Asked to name what something is ("is it cancer?") | We cannot tell you what it is. That needs somebody who can examine Bruno, and naming a possibility here would be a guess dressed up as an answer — which is worse than saying nothing. Ring your vet and describe what you are seeing. | Refuses before looking anything up | |
| J47 | Nothing on record matches | We hold 13 things about Bruno, and none of them speak to what you have described. That is a gap in what we know, not a judgement about Bruno — if it is worrying you, it is worth a call to your vet. | Admits the gap instead of filling it | |
| J48 | Record matches — opening | Here is what is already on Bruno's record about that. |  | |
| J49 | Record matches, a risk involved — closing | This is recall, not an opinion — we have not examined Bruno and cannot tell you what it is. Given what is on the record, it is worth a vet's eyes. | Routes to a vet, names nothing | |
| J50 | A model reply failed verification | We could not put together an answer we are confident enough to show you about Bruno. That is our problem rather than yours — everything we hold is on their record, and if something is worrying you it is worth a call to your vet. | Discards uncited output (C3) | |
| J51 | Asked for a vet — headline | We cannot put you through to a vet ourselves |  | |
| J52 | Asked for a vet — body | There is no video vet behind Clovara yet, and pretending otherwise would waste the time of somebody who needs one. What we can do is make the appointment you book go better. | No telehealth partner yet (B3) | |
| J53 | Asked for a vet — what we can do | Copy Bruno's summary — everything on their record, in one page a vet can read in thirty seconds. |  | |
| J54 | Asked for a vet — what we can do | Ring your own practice. Out of hours, their number will tell you who covers them. |  | |
| J55 | Asked for a vet — what we can do | If it cannot wait, search for an emergency vet near you, or ring a poison line — they will tell you where to go. |  | |

## 5 · When a pet has died

The defensive Remember pass (SPEC-HORIZON §2.5). Read it as somebody whose dog died yesterday. **The quiet lines on Rewards, Care and Coverage were written by Claude Code in U4 and have not been read by anyone.**

| id | Where | Exact words | Why it is judgement | Verdict |
|---|---|---|---|---|
| J56 | Health File — before telling us | If Bruno has died, telling us stops everything — the reminders, the suggestions, the questions. Nothing is deleted. |  | |
| J57 | Health File — after | Bruno's record is still here |  | |
| J58 | Health File — after | We have stopped everything that would have carried on — the reminders, the suggestions, the questions about how Bruno is doing. Nothing has been deleted, and nothing will be. Whenever you want it, it is here. |  | |
| J59 | Health File — after | Nothing else is needed from you. | Asks for nothing — no cause, no rating, no next pet | |
| J60 | Health File — after | Undo — this was a mistake |  | |
| J61 | Home — the nudge | Everything you told us is kept. Nothing else is needed from you. |  | |
| J62 | Rewards tab | Nothing is being counted for Bruno any more. | Written in U4 — unread | |
| J63 | Care tab | The companion has stopped. Everything it knew about Bruno is in their record, and the one-page summary is still there if a vet ever asks for it. | Written in U4 — unread | |
| J64 | Coverage and Protect tab | There is no cover to offer for Bruno, and we are not going to price one. | Written in U4 — unread | |
| J65 | Shop tab | There is nothing here for Bruno. Everything on this shelf was chosen from their plan, and we are not going to keep selling to you. |  | |
| J66 | Life — the hero | Bruno's life · 12 years · [born] – [died] | Replaces the healthy-years forecast | |
| J67 | Life — the stages | The stages Bruno lived through. · Lived through · The stage they reached | Replaces "what to plan for" | |

## 6 · The senior suite

What the product says about an old animal — and what it refuses to (P4: no quality-of-life score).

| id | Where | Exact words | Why it is judgement | Verdict |
|---|---|---|---|---|
| J68 | Opening | Nothing here is about slowing anything down. It is about the house being easier to live in, and about the handful of things you see at home that a vet cannot see in ten minutes. |  | |
| J69 | The refusal | We do not score how good your pet’s life is. Scales for that exist and they belong with a vet who knows them and knows your animal — not with an app making a number out of six tick boxes. | No quality-of-life score, deliberately | |
| J70 | Worth mentioning — note | None of these mean anything on their own, and we are not going to tell you what they might be. They are worth saying out loud at the next appointment, which is all. | Observations, never named as conditions | |
| J71 | Worth mentioning at the next visit (dog) | Slower to get up, or settling with more shuffling than they used to. |  | |
| J72 | Worth mentioning at the next visit (dog) | Hesitating at stairs, or at the car, when they did not before. |  | |
| J73 | Worth mentioning at the next visit (dog) | Drinking more, or asking to go out in the night. |  | |
| J74 | Worth mentioning at the next visit (dog) | Restless or unsettled in the evenings. |  | |
| J75 | Worth mentioning at the next visit (dog) | Going off their food, or eating more slowly. |  | |
| J76 | Worth mentioning at the next visit (dog) | Less interested in a walk they used to like. |  | |
| J77 | Worth mentioning at the next visit (cat) | Stopped jumping to somewhere they always used to sit. |  | |
| J78 | Worth mentioning at the next visit (cat) | Grooming less, or matting behind the shoulders. |  | |
| J79 | Worth mentioning at the next visit (cat) | Drinking more, or spending longer at the water bowl. |  | |
| J80 | Worth mentioning at the next visit (cat) | Going outside the tray, or standing differently in it. |  | |
| J81 | Worth mentioning at the next visit (cat) | Sleeping somewhere new, especially somewhere warmer. |  | |
| J82 | Worth mentioning at the next visit (cat) | Louder at night, or awake when the house is not. |  | |

## 7 · Records that refuse to interpret

The lump diary never says whether a lump grew; the vet summary omits the projection; the second opinion never second-guesses the vet. **All three are P4 refusals.**

| id | Where | Exact words | Why it is judgement | Verdict |
|---|---|---|---|---|
| J83 | Lump diary | The same thing, month after month |  | |
| J84 | Lump diary | A lump you have just found is a reason to see a vet, not a reason to start a diary. This is for keeping track of something a vet has already looked at and asked you to watch. |  | |
| J85 | Vet summary | Everything about Bruno, on one page |  | |
| J86 | Vet summary | What you would be asked in the room and would not remember. Copy it, send it ahead, or read it off your phone. |  | |
| J87 | Vet summary | Everything below was reported by you through this app. None of it has been examined or verified by a vet, and a blank means the question was never asked — not that the answer is no. |  | |
| J88 | Vet summary — the caveat | Everything below was reported by you through this app. None of it has been examined or verified by a vet, and a blank means the question was never asked — not that the answer is no. |  | |
| J89 | Second opinion | Tell us what you were told — the procedure, the number, whatever you can remember. Nothing is stored and nothing is sent anywhere. |  | |
| J90 | Second opinion | What were you told about Bruno? |  | |
| J91 | Second opinion — under the questions | These are questions, not doubts. We have not examined your pet, we do not know what your vet knows, and nothing here suggests the recommendation is wrong — only that it is yours to understand before you agree to it. |  | |

## 8 · Buying cover — the disclosures

Protect's second step, "the uncomfortable page, on purpose". **This whole section is counsel's (A2); CA/NY auto-renewal wording is not drafted and must not be.**

| id | Where | Exact words | Why it is judgement | Verdict |
|---|---|---|---|---|
| J92 | Price | Illustrative — rates are not yet filed. This is an estimate, not an offer. |  | |
| J93 | Before the declaration | Cover cannot be bought yet — binding waits on the carrier programme. The button below will not buy anything or take any money; it is here so you can see the whole flow. | Written in U7 — unread | |
| J94 | Declaration | Everything I have told Clovara about my pet is accurate as far as I know, and I have read what is and is not covered. |  | |
| J95 | When bind is pressed | Binding is not live yet — the carrier programme has to be in place first. Nothing has been bought and nothing has been charged. | Reworded in U7 | |
| J96 | Nothing declared | You have not told us about anything diagnosed, so nothing is excluded as pre-existing today. If something is found before Max's cover starts, it would be. |  | |
| J97 | Waiting period — Accidents (3 days) | Short, because an accident is not something anyone saw coming. |  | |
| J98 | Waiting period — Illness (14 days) | Long enough that a policy cannot be bought for something already brewing, which is what keeps it affordable for everyone else. |  | |
| J99 | Waiting period — Cruciate and other orthopaedic conditions (180 days) | The longest one, and the one worth knowing about before you need it. Joint problems develop slowly and are the most commonly claimed-for thing in large dogs. |  | |
| J100 | Disclosure — Anything already there is not covered | A condition that showed signs before your policy started, or during a waiting period, is not covered — whether or not it had been diagnosed. This is the single most common reason a claim is declined, and it is why the page before this one lists what we already know about. |  | |
| J101 | Disclosure — This price is illustrative | Rates have not been filed with your state regulator yet. The figure shown is our best current estimate of what the filed rate will be, and the price you are actually offered may differ. |  | |
| J102 | Disclosure — Insurance is separate from membership | Your Clovara membership and your insurance premium are two different things, billed as two different lines. Cancelling one does not cancel the other, and membership points never reduce a premium. |  | |
| J103 | Disclosure — It renews, and the price can change | The policy renews annually. The premium at renewal reflects your pet getting older, claims experience, and any change to our filed rates — never anything measured by a tracker or said to the companion. |  | |
| J104 | Disclosure — You can cancel | Cancel at any time. Depending on your state you may be entitled to a refund of unearned premium; the policy documents set out how that is calculated. |  | |
| J105 | Fraud notice | Any person who knowingly and with intent to defraud an insurer files a claim or application containing materially false information, or conceals information concerning any material fact, commits a fraudulent insurance act, which is a crime and may subject that person to criminal and civil penalties. State-specific wording will replace this notice once filings are complete. | Legal text — counsel | |

## 9 · The Data Covenant

The promise about what is never done with what an owner tells us (invariant 5). **Counsel (A2)**, and it is the page most likely to be quoted back at us.

| id | Where | Exact words | Why it is judgement | Verdict |
|---|---|---|---|---|
| J106 | Data Covenant — opening | Clovara knows things about your pet that could be used against you. This page is our promise about what we will never do with them, written before we had any reason to need it. |  | |
| J107 | Data Covenant — What we hold | What you have told us: the breed, the birthday, the weight, anything already diagnosed, how the days go. What a tracker sends, if you ever wear one on them. What you and the companion have talked about. |  | |
| J108 | Data Covenant — What we hold | That is a real picture of an animal, and it is the reason the plan is any good. It is also, in the wrong hands, a list of reasons to charge someone more. |  | |
| J109 | Data Covenant — What it is never used for | These are the ones that matter, so they are first and they are plain. |  | |
| J110 | Data Covenant — What it is never used for | Nothing you tell the companion is used to decide a claim. Not to question one, not to delay one, not to deny one. |  | |
| J111 | Data Covenant — What it is never used for | Nothing a tracker records is used to decide a claim either. A quiet week is not evidence of anything. |  | |
| J112 | Data Covenant — What it is never used for | Your data does not change your premium. Not up, and not down as a reward for behaving — which is the same promise, and it is the one that keeps the first two honest. |  | |
| J113 | Data Covenant — What it is never used for | We do not sell it. Not to brokers, not to advertisers, not to anyone building a model to price people. |  | |
| J114 | Data Covenant — The companion is firewalled | It helps you notice things and tells you when to call a vet. It does not diagnose, it does not prescribe, and it is not a route into underwriting or claims — the people and systems that decide those never see the conversation. |  | |
| J115 | Data Covenant — The companion is firewalled | That separation is deliberate. A companion you are careful in front of is useless, and one you are honest with only works if honesty is free. |  | |
| J116 | Data Covenant — What it does get used for | Your pet, first. Everything here exists to make their plan sharper and their care easier. |  | |
| J117 | Data Covenant — What it does get used for | And, in aggregate, the science. Pooled across thousands of animals with nothing identifying in it, this data can answer questions the published literature currently cannot — which is how a breed moves from an illustrative figure to a real one. Nothing in that work traces back to a name, an address, or a policy. |  | |
| J118 | Data Covenant — The one exception, stated plainly | A rated programme — where a tracker genuinely earns someone a different price — is a thing insurers do, and one day we may offer it. If we ever do, it will be a separate product you choose on purpose: filed with the regulator, priced transparently, explained before you opt in, and leavable. |  | |
| J119 | Data Covenant — The one exception, stated plainly | It will never be this. Joining Clovara does not enrol you in it, and no data you have already given us would be used to price you under it without you saying yes first. |  | |
| J120 | Data Covenant — What you can do about it | Ask us for everything we hold on your pet and we will send it in a form you can actually read. Ask us to delete it and we will, including from the aggregate work where it has not already been anonymised beyond recovery. |  | |
| J121 | Data Covenant — What you can do about it | You do not have to give a reason, and asking does not affect your membership or any policy. |  | |
| J122 | Data Covenant — If this ever changes | A promise you can quietly edit is not a promise. If we change anything on this page we will say so directly — not in a version note — and the old wording will stay readable beside the new one. |  | |

## 10 · Standing disclaimers

Shown on every visit to their tab.

| id | Where | Exact words | Why it is judgement | Verdict |
|---|---|---|---|---|
| J123 | Coverage | Illustrative pricing shown to demonstrate how rate varies with species, size, age and breed. Not a quote and not a filed rate. |  | |
| J124 | Rewards | Points redeem toward products and care services only, never toward your premium. Streak data in this preview is simulated. |  | |
| J125 | Coverage — no claims yet | Nothing can be claimed yet: no policy can be bought until the carrier programme is in place. This is how it is designed to work. | Written in U7 — unread | |
| J126 | Site footer | Clovara Life shares information to support care decisions. It is not veterinary advice; your veterinarian decides care. Pricing, products and activity data in this preview are illustrative. |  | |
