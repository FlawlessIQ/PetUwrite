# AI-Powered Conversational Quote Flow

## Overview

The conversational quote flow has been enhanced with real AI-powered interactions, making it feel natural, empathetic, and intelligent. Instead of static, pre-written questions, the bot now uses GPT to generate contextual responses, correct user inputs, and show empathy for sensitive topics.

---

## 🤖 Key Features

### 1. **Dynamic AI-Generated Questions**
- Questions adapt based on previous answers
- Natural language flow instead of form-style questions
- Personalizes using pet and owner names in context

**Example:**
```
Static: "What breed is your pet?"
AI-Powered: "That's a beautiful name for a Golden Retriever! Is Buddy neutered or spayed?"
```

### 2. **Intelligent Input Validation & Correction**

#### Name Capitalization
- Automatically capitalizes names properly
- Input: "john smith" → Output: "John Smith"
- Input: "FLUFFY" → Output: "Fluffy"

#### Breed Name Correction
- Fixes spelling errors in breed names
- Recognizes common abbreviations
- Asks for confirmation when correcting

**Examples:**
- "golden retriver" → "Golden Retriever" (with confirmation)
- "lab" → "Labrador Retriever"
- "gsd" → "German Shepherd"
- "mut" → "Mixed Breed"

### 3. **Empathetic Health Responses**

When users mention serious health conditions, the AI generates compassionate responses:

**User Input:** "My dog has cancer"

**AI Response Examples:**
- "I'm so sorry to hear Luna is dealing with cancer. We're here to help find coverage that can support her through this journey."
- "Thank you for trusting us with this. Even with a cancer diagnosis, we can help find the right protection for Max's care."

**Triggers empathy for:**
- Cancer, tumors, lymphoma, leukemia
- Terminal conditions
- Critical/emergency situations
- Other serious diagnoses

### 4. **Contextual Conversation Flow**

The AI maintains context throughout the conversation:

```
Bot: "Hi! I'm here to help you protect your furry friend. What's your name?"
User: "Sarah"

Bot: "Great to meet you, Sarah! What's your pet's name?"
User: "Max"

Bot: "Max is a wonderful name! Is Max a dog or a cat?"
User: "Dog"

Bot: "Perfect! What breed is Max?"
```

---

## 🔧 Technical Implementation

### Architecture

```
┌─────────────────────────────────────┐
│ ConversationalQuoteFlow (UI)       │
│  - Handles user interactions        │
│  - Streams bot messages             │
│  - Manages conversation state       │
└────────────┬────────────────────────┘
             │
             ↓
┌─────────────────────────────────────┐
│ ConversationalAIService             │
│  - Validates & corrects input       │
│  - Generates bot responses          │
│  - Detects empathy triggers         │
└────────────┬────────────────────────┘
             │
             ↓
┌─────────────────────────────────────┐
│ GPTService (gpt-4o-mini)            │
│  - Faster, cheaper for conversations│
│  - Generates natural language       │
│  - Handles corrections              │
└─────────────────────────────────────┘
```

### Key Components

#### 1. **ConversationalAIService** (`lib/services/conversational_ai_service.dart`)

**Methods:**

**`generateBotResponse()`**
```dart
Future<String> generateBotResponse({
  required String questionId,
  required String baseQuestion,
  required String userAnswer,
  required Map<String, dynamic> conversationContext,
}) async
```
Generates contextual, natural bot questions based on:
- Current question ID
- User's previous answer
- Full conversation context
- Pet/owner names

**`validateAndCorrectInput()`**
```dart
Future<Map<String, dynamic>> validateAndCorrectInput({
  required String questionId,
  required String userInput,
  required Map<String, dynamic> context,
}) async
```
Returns:
```dart
{
  'corrected': String,        // Corrected input
  'needsConfirmation': bool,  // Whether to ask user to confirm
  'message': String?,         // Optional AI message to display
  'isSerious': bool?,         // Whether it's a serious health condition
}
```

**`generateEmpatheticResponse()`**
```dart
Future<String> generateEmpatheticResponse({
  required String condition,
  required String petName,
}) async
```
Generates compassionate responses for health conditions.

#### 2. **Updated ConversationalQuoteFlow**

**Changes:**

**Added AI Service:**
```dart
late ConversationalAIService _aiService;

@override
void initState() {
  super.initState();
  _aiService = ConversationalAIService();
  _startConversation();
}
```

**Enhanced `_handleUserResponse()`:**
- Validates text inputs with AI
- Corrects spelling/capitalization
- Shows empathetic messages for health conditions
- Asks for confirmation when needed

**Enhanced `_showNextQuestion()`:**
- Generates AI-powered questions
- Uses conversation context
- Falls back to base questions if AI fails
- Maintains natural flow

---

## 🎯 User Experience Flow

### Example: Complete Conversation

```
Bot: "Hi! I'm here to help you protect your furry friend. What's your name?"
User: "sarah johnson"
[AI corrects to: "Sarah Johnson"]

Bot: "Great to meet you, Sarah! What's your pet's name?"
User: "BUDDY"
[AI corrects to: "Buddy"]

Bot: "Buddy is a perfect name! Is Buddy a dog or a cat?"
User: "Dog"

Bot: "Wonderful! What breed is Buddy?"
User: "golden retriver"
[AI detects spelling error]

Bot: "Just to confirm, you said Golden Retriever, right?"
User: "Yes"

Bot: "Perfect! How old is Buddy?"
User: "8"

Bot: "Does Buddy have any pre-existing health conditions?"
User: "Yes"

Bot: "Which health conditions does Buddy have?"
User: "he has cancer"
[AI detects serious condition]

Bot: "I'm so sorry to hear Buddy is dealing with cancer. We're here to help find the right coverage to support Buddy's health journey. Are these conditions currently being treated?"
```

---

## 🔑 Key Prompts

### 1. **Bot Response Generation**

```
You are a friendly, professional pet insurance advisor having a natural conversation. 

Context:
- Owner's name: Sarah Johnson
- Pet's name: Buddy
- Current question: breed
- User just answered: "Golden Retriever"

Base question to ask next: "How old is {petName}?"

Task: Rewrite the next question to be warm, natural, and conversational. 
- Use the pet's name when relevant
- Keep it concise (1-2 sentences max)
- Match the tone to the answer (if they mentioned something serious, be empathetic)
- Make it feel like a real conversation, not a form

Natural response:
```

### 2. **Breed Validation**

```
The user entered a pet breed. Validate and correct it if needed.

Species: Dog
User input: "golden retriver"

Task:
1. If it's a valid breed name, return it with proper capitalization
2. If it's misspelled, return the corrected breed name
3. If it's unclear or invalid, return null

Return ONLY the corrected breed name or "INVALID" if not a real breed.

Examples:
- "golden retriver" → "Golden Retriever"
- "lab" → "Labrador Retriever"
- "gsd" → "German Shepherd"

Corrected breed:
```

### 3. **Empathetic Health Response**

```
You are a compassionate pet insurance advisor. A pet owner just mentioned their pet has a health condition.

Pet's name: Buddy
Condition mentioned: cancer

Generate a brief (1-2 sentences), warm, empathetic response that:
1. Acknowledges the condition with care and understanding
2. Reassures them that coverage is still possible
3. Uses the pet's name
4. Keeps a positive, supportive tone

Response:
```

---

## ⚡ Performance Considerations

### Model Selection
- **gpt-4o-mini** for conversation generation
  - Faster responses (< 1s typically)
  - Lower cost (~$0.15 per 1M tokens)
  - Good enough quality for conversational text

- **gpt-4o** only for risk scoring (complex analysis)

### Caching & Fallbacks
- All AI calls have fallbacks to base questions
- If AI fails, conversation continues with pre-written questions
- No blocking - streaming continues even during AI generation

### Cost Estimation
- Average conversation: ~2,000 tokens
- Cost per conversation: ~$0.0003 (less than a cent)
- 10,000 conversations/month: ~$3

---

## 🧪 Testing Examples

### Test Case 1: Name Capitalization
```dart
Input: "john smith"
Expected: "John Smith"
```

### Test Case 2: Breed Correction
```dart
Input: "golden retriver"
Expected: Confirmation message + "Golden Retriever"
```

### Test Case 3: Abbreviation Expansion
```dart
Input: "lab"
Expected: "Labrador Retriever"
```

### Test Case 4: Empathy for Cancer
```dart
Input: "My dog has cancer"
Expected: Empathetic message mentioning pet name
```

### Test Case 5: Multiple Conditions
```dart
Input: "arthritis and diabetes"
Expected: Corrected capitalization + acknowledgment
```

---

## 📊 Benefits

### User Experience
✅ **More Natural:** Feels like talking to a human, not filling a form  
✅ **Forgiving:** Corrects typos automatically  
✅ **Empathetic:** Shows understanding for difficult situations  
✅ **Smart:** Recognizes abbreviations and common terms  
✅ **Personalized:** Uses names and context throughout  

### Business Impact
✅ **Higher Completion Rates:** Better UX = more completed quotes  
✅ **Better Data Quality:** Corrected inputs = accurate risk assessment  
✅ **Emotional Connection:** Empathy builds trust  
✅ **Reduced Errors:** Auto-correction reduces form abandonments  
✅ **Scalable:** AI handles variations without manual updates  

---

## 🚀 Future Enhancements

### Phase 2: Voice of Customer
- Detect tone/sentiment in answers
- Adjust bot personality dynamically
- Offer assistance for confused users

### Phase 3: Proactive Guidance
- Suggest breed if user says "I don't know"
- Explain why questions matter
- Offer examples for unclear questions

### Phase 4: Memory & Context
- Remember user from previous visits
- Reference past conversations
- Pre-fill known information

### Phase 5: Multi-language
- Detect user language
- Respond in same language
- Translate breed names appropriately

---

## 🔧 Configuration

### Environment Variables
```bash
OPENAI_API_KEY=sk-...  # Required for AI features
```

### Model Selection
Edit in `conversational_ai_service.dart`:
```dart
ConversationalAIService({String? apiKey}) 
    : _aiService = GPTService(
        apiKey: apiKey ?? dotenv.env['OPENAI_API_KEY'] ?? '',
        model: 'gpt-4o-mini', // Change model here
      );
```

### Empathy Triggers
Edit in `conversational_ai_service.dart`:
```dart
final seriousConditions = [
  'cancer',
  'tumor',
  'leukemia',
  'lymphoma',
  'terminal',
  'dying',
  'critical',
  'emergency',
  // Add more here
];
```

---

## 📝 Error Handling

All AI operations have graceful fallbacks:

1. **AI Response Generation Fails**
   → Falls back to base question with placeholder replacement

2. **Breed Validation Fails**
   → Uses basic capitalization

3. **Empathy Response Fails**
   → Shows generic supportive message

4. **No API Key**
   → Disables AI features, uses static flow

---

## ✅ Completion Checklist

- [x] ConversationalAIService created
- [x] AI integration in ConversationalQuoteFlow
- [x] Name capitalization working
- [x] Breed correction implemented
- [x] Empathetic health responses
- [x] Error handling with fallbacks
- [x] Documentation complete
- [ ] Testing with real users
- [ ] Cost monitoring dashboard
- [ ] A/B test vs static flow

---

*Last Updated: October 8, 2025*  
*Status: ✅ Production Ready*  
*AI Model: gpt-4o-mini*
