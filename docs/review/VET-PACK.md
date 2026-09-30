# The vet pack

*Generated from the code by `npm run review:packs` — do not edit by hand. `verify:all` fails if this file no longer matches what the app says, so what you sign off is what ships.*

Everything in Clovara Life that a vet should read before a real owner sees it (BACKLOG **A1**,
**R1**). Each item is the exact words, where they appear, and a Verdict line. Nothing here has
been read by a vet. The rule the whole product is built on: it can tell someone to ring a vet,
it never tells them what something is, and it never tells them it is fine.

**The one thing to look at hardest:** section 2's thresholds. They are never shown to anyone —
they decide whether a poison lookup says "ring now", "vet today" or "watch" — and they are ours,
not a published source.

## 1. "Something is wrong" — the escalation ladder

### V1 · When a sign on the list matches — headline

> Stop and ring a vet now.

- **Where:** The "something is wrong" screen
- **Verdict:** keep · change (write the change) · discuss

### V2 · When a sign matches — body

> From what you have written, this is not something to watch and see. Ring your own practice — out of hours they will have a number that is answered — or the nearest emergency vet. If you are not sure, ring anyway. Nobody minds the call that turned out to be nothing.

- **Where:** The "something is wrong" screen
- **Verdict:** keep · change (write the change) · discuss

### V3 · When nothing matches — headline

> We have not spotted anything on our urgent list.

- **Where:** The "something is wrong" screen
- **Must never read as reassurance.**
- **Verdict:** keep · change (write the change) · discuss

### V4 · When nothing matches — body

> That is a statement about our list, not about your pet. We match a short set of signs that always need a vet immediately, and plenty of serious things are not on it. If you are worried, ring your practice — you know them and we do not.

- **Where:** The "something is wrong" screen
- **Verdict:** keep · change (write the change) · discuss

### V5 · Red flag: Collapsed, or will not get up

> An animal that cannot stand needs to be seen now, whatever the cause.

- **Where:** Escalates to "Stop and ring a vet now" — dogs and cats
- **Matched when an owner writes words like:** collapse · collapsed · collaped · passed out · fainted · unresponsive · wont get up · won't get up · cannot get up · get up · cannot stand · can't stand · unconscious · went floppy · gone floppy · went limp · gone limp · all limp · funny turn · went stiff
- **Verdict:** keep · change (write the change) · discuss

### V6 · Red flag: Struggling to breathe

> Breathing trouble is the one thing that does not wait, and it can look mild minutes before it does not.

- **Where:** Escalates to "Stop and ring a vet now" — dogs and cats
- **Matched when an owner writes words like:** struggling to breathe · strugling to breath · struggling to breath · difficulty breathing · trouble breathing · laboured breathing · labored breathing · gasping · choking · cannot breathe · can't breathe · not breathing · breathing funny · breathing fast · breathing a bit fast · breathing quickly · breathing heavy · breathing hard · breathing weird · wheezing · blue gums · grey gums · gray gums · blue tongue · gums look blue · gums are blue · gums look grey · gums look gray · tongue looks blue
- **Verdict:** keep · change (write the change) · discuss

### V7 · Red flag: Open-mouth breathing or panting

> A panting cat is not a hot cat. Cats almost never pant, and one that is doing it needs to be seen now.

- **Where:** Escalates to "Stop and ring a vet now" — cats only
- **Matched when an owner writes words like:** open mouth breathing · panting · breathing with mouth open · mouth open breathing
- **Verdict:** keep · change (write the change) · discuss

### V8 · Red flag: A seizure, or fitting

> A first seizure, a long one, or several close together all need a vet the same day.

- **Where:** Escalates to "Stop and ring a vet now" — dogs and cats
- **Matched when an owner writes words like:** seizure · siezure · seizeure · seazure · seizing · fitting · convulsing · convulsion · twitching uncontrollably · paddling
- **Verdict:** keep · change (write the change) · discuss

### V9 · Red flag: Straining in the litter tray

> In a male cat this can be a blockage, and it becomes life-threatening in hours rather than days. It is the single most time-critical thing on this list.

- **Where:** Escalates to "Stop and ring a vet now" — cats only
- **Matched when an owner writes words like:** straining to pee · straining to urinate · cannot pee · can't pee · not peed · hasn't peed · hasnt peed · not urinated · not weed · cannot wee · trying to pee · nothing coming out · nothing is coming out · no urine · blocked · in and out of the litter · keeps going to the litter · going to the litter tray · keeps going in the litter · in and out of the tray · squatting · crying in the litter
- **Verdict:** keep · change (write the change) · discuss

### V10 · Red flag: Swollen belly, retching with nothing coming up

> A swollen abdomen with unproductive retching is an emergency in any dog and especially a deep-chested one. Hours matter.

- **Where:** Escalates to "Stop and ring a vet now" — dogs only
- **Matched when an owner writes words like:** swollen belly · bloated · distended · hard belly · retching · trying to be sick · unproductive vomiting · dry heaving · heaving
- **Verdict:** keep · change (write the change) · discuss

### V11 · Red flag: Bleeding that will not stop

> Press on it with something clean and go. Judging how much blood is too much is not something to do at home.

- **Where:** Escalates to "Stop and ring a vet now" — dogs and cats
- **Matched when an owner writes words like:** bleeding · blood · blood everywhere · wont stop bleeding · won't stop bleeding · haemorrhage · hemorrhage
- **Verdict:** keep · change (write the change) · discuss

### V12 · Red flag: Hit, fallen, or crushed

> Serious internal injury is common after impact and often shows nothing at all at first.

- **Where:** Escalates to "Stop and ring a vet now" — dogs and cats
- **Matched when an owner writes words like:** hit by a car · hit by car · run over · fell from · fell off · crushed · stood on · attacked · attacked by · bitten by a dog · dog attack · mauled · in a fight · got into a fight · bitten by
- **Verdict:** keep · change (write the change) · discuss

### V13 · Red flag: Pale, white or tacky gums

> Gum colour is one of the few things an owner can check that genuinely changes the urgency.

- **Where:** Escalates to "Stop and ring a vet now" — dogs and cats
- **Matched when an owner writes words like:** pale gums · white gums · tacky gums · gums are pale · gums look white · gums to look white · gums look pale · gums are white · funny colour · funny color · gums are a funny · gum colour · gums look
- **Verdict:** keep · change (write the change) · discuss

### V14 · Red flag: Ate something they should not have

> For most of what is dangerous, treatment works best before an animal looks unwell.

- **Where:** Escalates to "Stop and ring a vet now" — dogs and cats
- **Matched when an owner writes words like:** ate rat poison · ate poison · antifreeze · chocolate · grapes · raisins · ate raisins · xylitol · ate a lily · ate my tablets · ate ibuprofen · ate paracetamol · swallowed a battery
- **Verdict:** keep · change (write the change) · discuss

### V15 · Red flag: Overheated

> Heatstroke does damage that continues after the animal looks cooler.

- **Where:** Escalates to "Stop and ring a vet now" — dogs and cats
- **Matched when an owner writes words like:** heatstroke · heat stroke · overheated · left in the car · too hot and
- **Verdict:** keep · change (write the change) · discuss

### V16 · Red flag: Sudden swelling of the face, or hives

> A reaction that is swelling a face can go on to affect breathing.

- **Where:** Escalates to "Stop and ring a vet now" — dogs and cats
- **Matched when an owner writes words like:** face is swollen · swollen face · hives · swollen muzzle · lips swollen · stung
- **Verdict:** keep · change (write the change) · discuss

### V17 · Red flag: Trouble giving birth

> Time between puppies or kittens is the thing that matters, and it is easy to leave too long.

- **Where:** Escalates to "Stop and ring a vet now" — dogs and cats
- **Matched when an owner writes words like:** in labour · in labor · straining to give birth · stuck · been pushing
- **Verdict:** keep · change (write the change) · discuss

### V18 · Red flag: A painful or injured eye

> Eyes do not wait. A day can be the difference between keeping and losing one.

- **Where:** Escalates to "Stop and ring a vet now" — dogs and cats
- **Matched when an owner writes words like:** eye is · scratched his eye · scratched her eye · eye popped · cannot see · can't see · gone blind · suddenly blind
- **Verdict:** keep · change (write the change) · discuss

### V19 · Red flag: In obvious pain

> An animal showing pain that plainly has usually been hiding it for a while.

- **Where:** Escalates to "Stop and ring a vet now" — dogs and cats
- **Matched when an owner writes words like:** screaming · crying out · yelping when · wont let me touch · won't let me touch · in agony · shaking and
- **Verdict:** keep · change (write the change) · discuss

### V20 · Red flag: Not eating

> A cat that stops eating for a couple of days can develop a serious liver problem from the fasting itself, whatever started it.

- **Where:** Escalates to "Stop and ring a vet now" — cats only
- **Matched when an owner writes words like:** not eaten · not eating · refusing food · off his food · off her food · wont eat · won't eat
- **Verdict:** keep · change (write the change) · discuss

### V21 · Red flag: Repeated vomiting or diarrhoea

> Dehydration happens quickly in a small animal, and blood changes the urgency.

- **Where:** Escalates to "Stop and ring a vet now" — dogs and cats
- **Matched when an owner writes words like:** keeps being sick · vomiting repeatedly · cannot keep water down · can't keep water down · blood in his stool · blood in her stool · bloody diarrhoea · bloody diarrhea · vomiting blood
- **Verdict:** keep · change (write the change) · discuss

## 2. "Ate something" — the poison lookup

### V22 · First thing on the screen

> Ring your vet or a poison line now. Do not wait for signs — for most of what is on this list, treatment works best before an animal looks unwell.

- **Where:** Top of "ate something"
- **Verdict:** keep · change (write the change) · discuss

### V23 · Never make them sick

> Do not try to make them sick. It is the wrong thing for some of what is on this list and it causes its own injuries — whether to do it at all is a decision for the person on the phone.

- **Where:** Top of "ate something"
- **Verdict:** keep · change (write the change) · discuss

### V24 · Take the packet

> Take the packet, the wrapper or a photograph of the plant with you. What it was matters more than how much, and it is the first thing you will be asked.

- **Where:** Top of "ate something"
- **Verdict:** keep · change (write the change) · discuss

### V25 · Footer

> This is information, not veterinary advice, and it is not a substitute for ringing someone. If you are not sure, ring. Nobody minds the call that turned out to be nothing.

- **Where:** Foot of "ate something"
- **Verdict:** keep · change (write the change) · discuss

### V26 · Grapes, raisins, sultanas or currants

> Why: The reaction is idiosyncratic — some dogs have gone into kidney failure after a handful, and others have eaten a punnet with nothing at all. Because nobody can tell which dog they have, there is no amount treated as safe.
> 
> What you might see: Vomiting, then being quiet or off food over the following day or two.

- **Where:** Poison lookup — dog
- **Urgency:** always "ring now", at any amount
- **Also found by:** grape, raisin, sultana, currant, mince pie, christmas pudding
- **Verdict:** keep · change (write the change) · discuss

### V27 · Xylitol or birch sugar

> Why: It acts at very small quantities and very quickly — a few pieces of sugar-free gum is enough for a small dog. It is increasingly in peanut butter, protein bars and some medicines.
> 
> What you might see: Wobbliness, weakness or collapse, sometimes within half an hour.

- **Where:** Poison lookup — dog, cat
- **Urgency:** always "ring now", at any amount
- **Also found by:** xylitol, birch sugar, sugar free gum, sugarfree, peanut butter, sweetener
- **Verdict:** keep · change (write the change) · discuss

### V28 · Lily — any part, including pollen

> Why: True lilies and daylilies cause kidney failure in cats. Chewing a leaf, drinking the vase water, or grooming pollen off their own coat is enough. Treatment works best before signs appear, which is why this is a now call rather than a wait-and-see.
> 
> What you might see: Drooling, vomiting, hiding, or not drinking. Often nothing at all at first.

- **Where:** Poison lookup — cat
- **Urgency:** always "ring now", at any amount
- **Also found by:** lily, lilies, easter lily, stargazer, daylily, pollen
- **Verdict:** keep · change (write the change) · discuss

### V29 · Antifreeze or screenwash

> Why: Very small amounts cause kidney failure, it tastes sweet so animals drink it willingly, and the window in which treatment works is measured in hours.
> 
> What you might see: Appearing drunk, then seeming to recover, then becoming very unwell a day or two later.

- **Where:** Poison lookup — dog, cat
- **Urgency:** always "ring now", at any amount
- **Also found by:** antifreeze, ethylene glycol, screenwash, coolant, radiator
- **Verdict:** keep · change (write the change) · discuss

### V30 · Rat or mouse poison

> Why: Different poisons do entirely different things and the treatment differs completely, so the packet matters more than the amount. Take a photograph of it before you leave the house.
> 
> What you might see: Often nothing for days, which is the danger. Later: bruising, bleeding, weakness, or fits.

- **Where:** Poison lookup — dog, cat
- **Urgency:** always "ring now", at any amount
- **Also found by:** rat poison, rodenticide, mouse bait, warfarin, bromadiolone, slug pellets
- **Verdict:** keep · change (write the change) · discuss

### V31 · Human painkillers — ibuprofen, paracetamol, aspirin, naproxen

> Why: Doses that are ordinary for a person damage the stomach, the kidneys or the liver in a dog, and cats cannot process paracetamol at all — a single tablet can kill a cat.
> 
> What you might see: Vomiting, being off food, dark or tarry stools. In cats, brown gums and laboured breathing.

- **Where:** Poison lookup — dog, cat
- **Urgency:** always "ring now", at any amount
- **Also found by:** ibuprofen, paracetamol, acetaminophen, aspirin, naproxen, nurofen, tylenol, advil, painkiller
- **Verdict:** keep · change (write the change) · discuss

### V32 · Cannabis or edibles

> Why: Edibles are the real problem, because they usually also contain chocolate or xylitol. Nobody is in trouble for saying what was eaten, and a vet needs to know to treat it properly.
> 
> What you might see: Wobbling, dribbling urine, startling at sounds, very dilated pupils.

- **Where:** Poison lookup — dog, cat
- **Urgency:** always "ring now", at any amount
- **Also found by:** cannabis, weed, thc, edible, marijuana, hash, gummies
- **Verdict:** keep · change (write the change) · discuss

### V33 · Sago palm

> Why: Every part is toxic and the seeds most of all. It causes liver failure and it is one of the least survivable things on this list if it waits.
> 
> What you might see: Vomiting, then jaundice a day or two later.

- **Where:** Poison lookup — dog, cat
- **Urgency:** always "ring now", at any amount
- **Also found by:** sago, cycad, cardboard palm, zamia
- **Verdict:** keep · change (write the change) · discuss

### V34 · Chocolate

> Why: The problem is theobromine, and how much is in it varies enormously — the same weight of baking chocolate carries roughly seven times what milk chocolate does.
> 
> What you might see: Restlessness, a racing heart, vomiting, tremors.

- **Where:** Poison lookup — dog, cat
- **Urgency:** banded by amount — **vet today from 8 mg/kg, ring now from 20 mg/kg of bodyweight** (never shown to anyone; it decides the band)
- **Forms and strengths used in the calculation:** White chocolate (0.1 mg/g); Milk chocolate (2 mg/g); Dark or plain (5.5 mg/g); Baking or cocoa powder (15 mg/g)
- **Also found by:** chocolate, cocoa, cacao, brownie, choc
- **Verdict:** keep · change (write the change) · discuss

### V35 · Onion, garlic, leek or chive

> Why: They damage red blood cells, and cats are considerably more sensitive than dogs. Powders and gravy granules are far more concentrated than the vegetable.
> 
> What you might see: Often nothing for a few days, then pale gums, tiredness, or orange-brown urine.

- **Where:** Poison lookup — dog, cat
- **Urgency:** banded by amount — **vet today from 1500 mg/kg, ring now from 4000 mg/kg of bodyweight** (never shown to anyone; it decides the band)
- **Forms and strengths used in the calculation:** Raw or cooked pieces (1000 mg/g); Powder or concentrate (5000 mg/g)
- **Also found by:** onion, garlic, leek, chive, shallot, gravy, stuffing
- **Verdict:** keep · change (write the change) · discuss

### V36 · Macadamia nuts

> Why: Dogs get weak in the back legs and feverish. It is rarely fatal and it is alarming to watch.
> 
> What you might see: Wobbliness or weakness in the back legs, tremors, a temperature.

- **Where:** Poison lookup — dog
- **Urgency:** banded by amount — **vet today from 600 mg/kg, ring now from 1500 mg/kg of bodyweight** (never shown to anyone; it decides the band)
- **Forms and strengths used in the calculation:** Nuts (1000 mg/g)
- **Also found by:** macadamia, nuts
- **Verdict:** keep · change (write the change) · discuss

### V37 · Coffee, tea or energy drinks

> Why: It does much what chocolate does, and grounds and tablets are far more concentrated than a cup of anything.
> 
> What you might see: Restlessness, a racing heart, vomiting, tremors.

- **Where:** Poison lookup — dog, cat
- **Urgency:** banded by amount — **vet today from 6 mg/kg, ring now from 14 mg/kg of bodyweight** (never shown to anyone; it decides the band)
- **Forms and strengths used in the calculation:** Brewed coffee or tea (0.4 mg/g); Grounds, beans or tea bags (12 mg/g); Caffeine tablets (200 mg/g)
- **Also found by:** coffee, caffeine, espresso, energy drink, tea bag, pro plus
- **Verdict:** keep · change (write the change) · discuss

### V38 · Raw bread dough

> Why: It keeps rising in a warm stomach and the yeast produces alcohol while it does. Both halves are dangerous and the swelling can be a surgical problem.
> 
> What you might see: A swollen, painful belly, retching without bringing anything up, appearing drunk.

- **Where:** Poison lookup — dog, cat
- **Urgency:** always "ring now", at any amount
- **Also found by:** dough, bread dough, yeast
- **Verdict:** keep · change (write the change) · discuss

### V39 · Alcohol

> Why: Animals are far smaller than us and far more sensitive, and it drops their blood sugar and their temperature as well as intoxicating them.
> 
> What you might see: Wobbliness, vomiting, cold, drowsy, slow breathing.

- **Where:** Poison lookup — dog, cat
- **Urgency:** always "ring now", at any amount
- **Also found by:** alcohol, beer, wine, spirits, vodka, whisky
- **Verdict:** keep · change (write the change) · discuss

### V40 · Vitamin D supplements

> Why: The margin between a human dose and a toxic one for an animal is very small, and it causes kidney damage that is hard to reverse once it is under way.
> 
> What you might see: Drinking and urinating much more than usual, vomiting, being off food.

- **Where:** Poison lookup — dog, cat
- **Urgency:** always "ring now", at any amount
- **Also found by:** vitamin d, cholecalciferol, supplement, psoriasis cream
- **Verdict:** keep · change (write the change) · discuss

### V41 · A battery, especially a button cell

> Why: A swallowed button cell can burn through tissue within hours. This is one of the few things on this list where the clock genuinely matters that much.
> 
> What you might see: Drooling, retching, refusing food, pawing at the mouth.

- **Where:** Poison lookup — dog, cat
- **Urgency:** always "ring now", at any amount
- **Also found by:** battery, button cell, coin cell, aa
- **Verdict:** keep · change (write the change) · discuss

### V42 · The phone numbers offered

> ASPCA Animal Poison Control — (888) 426-4435 — Open all hours. A consultation fee applies.
> Pet Poison Helpline — (855) 764-7661 — Open all hours. A consultation fee applies.
> Animal PoisonLine — 01202 509000 — Open all hours. A fee applies; it is cheaper than an unnecessary out-of-hours visit.

- **Where:** Both urgent screens
- **Verdict:** keep · change (write the change) · discuss

## 3. First Nights — the first 72 hours with a new puppy or kitten

### V43 · When to ring, at any hour (always visible)

> Call a vet now, at any hour, for: repeated vomiting or diarrhoea, a refusal to eat or drink for more than about twelve hours, gums that are pale or tacky, laboured breathing, collapse, a seizure, or a fall or crush injury. None of these are settling problems.

- **Where:** First Nights, and the first-night email
- **Verdict:** keep · change (write the change) · discuss

### V44 · The first few hours (hours 0–3, dog)

> Everything they know ended this morning. The single most useful thing you can do now is make the world small — one room, few people, no visitors.
> 
> Do now: Take them straight to the spot you want them to toilet in, and wait. Praise anything that happens. / Show them where water is. Leave it down and leave it there. / Let them sleep the moment they want to. Do not wake a sleeping puppy to play with them.
> 
> Normal right now: Hiding, shaking, refusing food, or sleeping for hours are all normal on the first afternoon.

- **Where:** First Nights
- **Verdict:** keep · change (write the change) · discuss

### V45 · The first evening (hours 3–8, dog)

> Set the pattern you actually want tonight, because whatever happens tonight is the pattern they will expect tomorrow.
> 
> Do now: Feed whatever the breeder or shelter was feeding, at the time they fed it. Change food later, slowly, or you will spend tomorrow cleaning. / Put the crate or bed where you intend it to live, and beside your bed for the first few nights. / Last toilet trip right before lights out, on the lead, no play.
> 
> Normal right now: Eating little or nothing on the first evening is common and not an emergency on its own.

- **Where:** First Nights
- **Verdict:** keep · change (write the change) · discuss

### V46 · The first night (hours 8–14, dog)

> They have never slept alone. Crying is not manipulation and it is not a behaviour problem — it is a puppy that has lost its litter.
> 
> Do now: Sleep near them. A hand through the crate door settles more puppies than any gadget. / Expect to get up. Under twelve weeks, most need the toilet at least once in the night. / Toilet trips at night are boring on purpose: out, wait, praise, back to bed. No lights, no play, no talking.
> 
> Normal right now: Waking two or three times is normal. So is crying for the first twenty minutes.

- **Where:** First Nights
- **Verdict:** keep · change (write the change) · discuss

### V47 · The first morning (hours 14–24, dog)

> Straight outside before anything else. The first week of toileting is almost entirely about your timing, not their training.
> 
> Do now: Out on waking, after every meal, after every nap, and after every burst of play. / Write down when they eat and when they go. Two days of that tells you their schedule better than any guide. / Book the first vet appointment today if it is not already booked.
> 
> Normal right now: Several accidents indoors today. That is the week, not a failure.

- **Where:** First Nights
- **Verdict:** keep · change (write the change) · discuss

### V48 · Day two (hours 24–48, dog)

> Appetite usually returns today. This is also when the second night is often worse than the first, because the novelty has worn off and the tiredness has not.
> 
> Do now: Keep the world small for one more day. Meeting the whole family and the neighbours can wait. / Start leaving them alone for two minutes at a time, while you are still in the house. / Handle their paws and ears for a few seconds, for nothing, so the vet is not the first person who does.
> 
> Normal right now: A worse second night is so common it is almost the rule.

- **Where:** First Nights
- **Verdict:** keep · change (write the change) · discuss

### V49 · Day three (hours 48–72, dog)

> Most puppies are eating normally and sleeping longer by now. What you build this week is the routine, not the obedience.
> 
> Do now: Same wake time, same meal times, same bed. Dull is what a settled animal is made of. / Ask your vet when they can safely meet other dogs — the socialisation window is short, and it is already open. / If they have still eaten nothing at all, call your vet today rather than waiting for the weekend.
> 
> Normal right now: Still having accidents, still crying at bedtime. Both normal at seventy-two hours.

- **Where:** First Nights
- **Verdict:** keep · change (write the change) · discuss

### V50 · The first few hours (hours 0–3, cat)

> A kitten does not want the run of the house. One quiet room with everything in it is not unkind — it is the only thing that makes the house survivable.
> 
> Do now: One room: litter tray at one end, food and water at the other, a box or bed to hide in. / Show them the tray, then leave them alone. Do not carry them around. / Let them come out when they come out. Sitting quietly in the room beats coaxing.
> 
> Normal right now: Going behind the sofa and staying there for hours is normal and is not fear of you.

- **Where:** First Nights
- **Verdict:** keep · change (write the change) · discuss

### V51 · The first evening (hours 3–8, cat)

> Cats settle by smell before anything else. The room smelling of them rather than of you is what turns it into somewhere they live.
> 
> Do now: Same food, same brand, as they were on. A diet change now usually means diarrhoea tomorrow. / Keep the tray far from the food. A cat that has to eat beside its toilet will pick somewhere else to go. / Play with a wand toy at their level for five minutes. It works better than picking them up.
> 
> Normal right now: Eating only once they think nobody is watching is normal.

- **Where:** First Nights
- **Verdict:** keep · change (write the change) · discuss

### V52 · The first night (hours 8–14, cat)

> Leave them in their room with the door shut. It sounds harsh at midnight and it is the reason night two is quiet.
> 
> Do now: Tray, water, somewhere to hide. Nothing else is needed. / Expect noise at 3am — kittens are crepuscular and yours has slept all afternoon. / Do not go in every time they call, or you have taught them what calling does.
> 
> Normal right now: Crying, and tearing around the room at four in the morning. Both normal.

- **Where:** First Nights
- **Verdict:** keep · change (write the change) · discuss

### V53 · The first morning (hours 14–24, cat)

> Check the tray before anything else — it is the best single piece of information you have about how they are doing.
> 
> Do now: Look for urine and for a formed stool. Note what you see. / Feed at a fixed time and take the bowl up between meals, so you can tell what they have actually eaten. / Book the first vet appointment today if it is not already booked.
> 
> Normal right now: Softer stools in the first days are common with the stress of moving.

- **Where:** First Nights
- **Verdict:** keep · change (write the change) · discuss

### V54 · Day two (hours 24–48, cat)

> Widen the world by one room, not by the whole house. Confidence in cats is built by letting them choose to come out.
> 
> Do now: Open the door and let them decide. Do not carry them to the new room. / Put a scratching post where they already scratch, not where it suits the furniture. / Handle paws and ears for a few seconds so a vet is not the first person to do it.
> 
> Normal right now: Going back to the first room and staying there is progress, not a setback.

- **Where:** First Nights
- **Verdict:** keep · change (write the change) · discuss

### V55 · Day three (hours 48–72, cat)

> Most kittens are eating properly and using the tray reliably by now. Everything else is routine and patience.
> 
> Do now: Keep the tray where it is. Moving it is the most common cause of a cat going elsewhere. / Ask your vet about the vaccination schedule and about when they can safely go out, if they ever will. / If they have still not used the tray at all, call your vet today.
> 
> Normal right now: Hiding at loud noises and sleeping sixteen hours a day. Both normal.

- **Where:** First Nights
- **Verdict:** keep · change (write the change) · discuss

### V56 · Footer

> This is information, not veterinary advice, and it never replaces your own vet. If something feels wrong to you, that is reason enough to call.

- **Where:** First Nights
- **Verdict:** keep · change (write the change) · discuss

## 4. Vaccinations

### V57 · What the schedule is

> Your vet sets the schedule, not us. Brands differ, local disease pressure differs, and the law differs — what is below is what a typical core course looks like so you know roughly what to expect and what to ask.

- **Where:** Health File → Vaccinations
- **Verdict:** keep · change (write the change) · discuss

### V58 · DHP / DAPP (dog)

> Distemper, hepatitis and parvovirus — the three that kill puppies.
> 
> First dose: usually 6–9 weeks
> Second dose: usually 10–13 weeks
> Third dose: usually 14–17 weeks
> First adult booster: usually 26–78 weeks

- **Where:** Health File → Vaccinations; calendar; reminder emails
- **Verdict:** keep · change (write the change) · discuss

### V59 · Rabies (dog)

> Rabies. Whether and when it is given is set by law where you live, not by us.
> 
> First dose: usually 12–20 weeks
> Booster: usually 52–78 weeks

- **Where:** Health File → Vaccinations; calendar; reminder emails
- **Law-dependent:** shown as "depends on local law"
- **Verdict:** keep · change (write the change) · discuss

### V60 · FVRCP (cat)

> Panleukopenia, herpesvirus and calicivirus — the core three for cats.
> 
> First dose: usually 6–9 weeks
> Second dose: usually 10–13 weeks
> Third dose: usually 14–21 weeks
> First adult booster: usually 26–78 weeks

- **Where:** Health File → Vaccinations; calendar; reminder emails
- **Verdict:** keep · change (write the change) · discuss

### V61 · Rabies (cat)

> Rabies. Whether and when it is given is set by law where you live, not by us.
> 
> First dose: usually 12–20 weeks
> Booster: usually 52–78 weeks

- **Where:** Health File → Vaccinations; calendar; reminder emails
- **Law-dependent:** shown as "depends on local law"
- **Verdict:** keep · change (write the change) · discuss

### V62 · Worth asking your vet about (dog)

> Leptospirosis — depends on where you walk and what the local picture is.
> Kennel cough — usually asked for by boarding kennels and some day care.
> Lyme — only in some regions, and only for some dogs.

- **Where:** Health File → Vaccinations
- **Verdict:** keep · change (write the change) · discuss

### V63 · Worth asking your vet about (cat)

> Feline leukaemia — the usual question for any cat who goes outside.
> Chlamydia and bordetella — occasionally, in multi-cat households.

- **Where:** Health File → Vaccinations
- **Verdict:** keep · change (write the change) · discuss

## 5. The senior suite

### V64 · Opening

> Nothing here is about slowing anything down. It is about the house being easier to live in, and about the handful of things you see at home that a vet cannot see in ten minutes.

- **Where:** Health File, older pets
- **Verdict:** keep · change (write the change) · discuss

### V65 · The refusal to score a life

> We do not score how good your pet’s life is. Scales for that exist and they belong with a vet who knows them and knows your animal — not with an app making a number out of six tick boxes.

- **Where:** Health File, older pets
- A deliberate choice (BACKLOG P4, X2)
- **Verdict:** keep · change (write the change) · discuss

### V66 · Worth mentioning — the note

> None of these mean anything on their own, and we are not going to tell you what they might be. They are worth saying out loud at the next appointment, which is all.

- **Where:** Health File, older pets
- **Verdict:** keep · change (write the change) · discuss

### V67 · Worth mentioning at the next visit (dog)

> Slower to get up, or settling with more shuffling than they used to.
> Hesitating at stairs, or at the car, when they did not before.
> Drinking more, or asking to go out in the night.
> Restless or unsettled in the evenings.
> Going off their food, or eating more slowly.
> Less interested in a walk they used to like.

- **Where:** Health File, older pets
- **Must stay observations — never named as conditions**
- **Verdict:** keep · change (write the change) · discuss

### V68 · Worth mentioning at the next visit (cat)

> Stopped jumping to somewhere they always used to sit.
> Grooming less, or matting behind the shoulders.
> Drinking more, or spending longer at the water bowl.
> Going outside the tray, or standing differently in it.
> Sleeping somewhere new, especially somewhere warmer.
> Louder at night, or awake when the house is not.

- **Where:** Health File, older pets
- **Must stay observations — never named as conditions**
- **Verdict:** keep · change (write the change) · discuss

### V69 · Around the house: Rugs or runners on hard floors

> Laminate and tile are the hardest thing in most houses for an older animal. A path of rugs between the bed, the door and the water bowl changes more than almost anything else you can buy.

- **Where:** Health File, older pets — dog, cat
- **Verdict:** keep · change (write the change) · discuss

### V70 · Around the house: A ramp or steps for the car and the sofa

> Jumping down is harder on joints than jumping up, and most dogs will use a ramp within a week if it is left out rather than produced at the car.

- **Where:** Health File, older pets — dog
- **Verdict:** keep · change (write the change) · discuss

### V71 · Around the house: A thicker, lower bed

> Thin bedding on a hard floor means pressure points. Low sides matter as much as the padding — a bed they have to climb into stops being a bed.

- **Where:** Health File, older pets — dog, cat
- **Verdict:** keep · change (write the change) · discuss

### V72 · Around the house: A litter tray with one low side

> Stepping over a high edge is often the reason a cat starts going elsewhere, and it is read as a behaviour problem far more often than it is one.

- **Where:** Health File, older pets — cat
- **Verdict:** keep · change (write the change) · discuss

### V73 · Around the house: Steps up to the windowsill or the bed

> Cats give up favourite places quietly rather than struggling in front of you. Somewhere they have stopped going is worth noticing.

- **Where:** Health File, older pets — cat
- **Verdict:** keep · change (write the change) · discuss

### V74 · Around the house: Water in more than one place

> Fewer trips across the house, and it makes it much easier to notice a change in how much they are drinking.

- **Where:** Health File, older pets — dog, cat
- **Verdict:** keep · change (write the change) · discuss

### V75 · Around the house: Shorter walks, more of them

> The same total, split up, is usually easier on an older dog than one long outing — and sniffing tires them out more kindly than distance does.

- **Where:** Health File, older pets — dog
- **Verdict:** keep · change (write the change) · discuss

### V76 · Around the house: A hand with grooming

> Cats who stop reaching their back end are not being lazy, and matted fur behind the shoulders is uncomfortable long before it looks bad.

- **Where:** Health File, older pets — cat
- **Verdict:** keep · change (write the change) · discuss

### V77 · Around the house: A night light on the route to the door

> Eyesight and confidence both go quietly. A lit path is a small thing that prevents a lot of stumbling and a lot of accidents.

- **Where:** Health File, older pets — dog, cat
- **Verdict:** keep · change (write the change) · discuss

### V78 · Around the house: Nails checked more often

> Less walking means less wear, and overgrown nails change how they stand — which makes everything else harder.

- **Where:** Health File, older pets — dog, cat
- **Verdict:** keep · change (write the change) · discuss

## 6. What the reminder emails say that is clinical

### V79 · Email: Bruno's first night, and what is normal

> Hiding, shaking, refusing food, or sleeping for hours are all normal in the first days. Keep the world small — one room, few people — and let Bruno come to you.
> 
> Call a vet now, at any hour, for: repeated vomiting or diarrhoea, a refusal to eat or drink for more than about twelve hours, gums that are pale or tacky, laboured breathing, collapse, a seizure, or a fall or crush injury. None of these are settling problems.
> 
> The hour-by-hour guide for the first three days is on Bruno's plan.

- **Where:** Reminder email (The first night (a puppy home since yesterday))
- **Verdict:** keep · change (write the change) · discuss

### V80 · Email: Around now is when Bruno's DHP / DAPP (second dose) is usually given

> Your vet sets the schedule, not us — brands, local disease and the law all differ. This is a reminder to check with them and book.
> 
> If Bruno has already had it, record it in the health file and we will stop mentioning it.

- **Where:** Reminder email (A vaccination window opening (ten weeks old))
- **Verdict:** keep · change (write the change) · discuss
