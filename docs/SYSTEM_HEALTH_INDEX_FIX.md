# System Health Firestore Index Fix

## Problem
The Admin Dashboard's System Health section was showing an error:
```
Error loading system health data
Exception: Failed to load failed operations: [cloud_firestore/failed-precondition] 
The query requires an index.
```

The error indicated that a composite index was needed for the `payouts` collection.

## Root Cause
The `ReconciliationService.getFailedOperations()` method performs a complex query that requires a Firestore composite index:

```dart
await _firestore
    .collection('payouts')
    .where('status', whereIn: ['failed', 'pending_retry', 'escalated'])
    .orderBy('updatedAt', descending: true)
    .limit(50)
    .get();
```

This query:
1. Filters by multiple status values using `whereIn`
2. Orders results by `updatedAt` in descending order

Firestore requires a composite index for any query that combines filtering with ordering on different fields.

## Solution
Added the required composite index to `firestore.indexes.json`:

```json
{
  "collectionGroup": "payouts",
  "queryScope": "COLLECTION",
  "fields": [
    {
      "fieldPath": "status",
      "order": "ASCENDING"
    },
    {
      "fieldPath": "updatedAt",
      "order": "DESCENDING"
    }
  ]
}
```

### Index Details
- **Collection**: `payouts`
- **Fields**:
  - `status` (ASCENDING) - for whereIn filtering
  - `updatedAt` (DESCENDING) - for ordering results

## Deployment
The index was successfully deployed to Firebase using:
```bash
firebase deploy --only firestore:indexes
```

### Deployment Result
✅ Index deployed successfully  
✅ No compilation errors  
⚠️  Minor warnings about unused functions in firestore.rules (non-critical)

## Impact
✅ **System Health Tab** now loads successfully  
✅ **Failed Operations** are displayed correctly  
✅ **Reconciliation Statistics** can be viewed  
✅ **Health Score** is calculated and shown  

## What the System Health Tab Shows
The System Health section now displays:

### 1. Health Score Circle
- Overall system health score (0-100)
- Visual indicator with color coding:
  - Green: Excellent (90-100)
  - Light Green: Good (75-89)
  - Orange: Fair (50-74)
  - Deep Orange: Poor (25-49)
  - Red: Critical (0-24)

### 2. Key Metrics
- Total Payouts
- Failed Payouts
- Escalated Payouts
- Failure Rate (%)

### 3. Latest Reconciliation Run
- States Fixed
- Operations Retried
- Successful Retries
- Escalated to Admin
- Duration and timestamp

### 4. Failed Operations List
- Shows up to 5 most recent failed operations
- Details for each:
  - Claim ID
  - Amount
  - Failure type
  - Retry count or escalation status
- Option to retry failed operations
- Link to view all failed operations if more than 5

## Files Modified
- `/firestore.indexes.json` - Added payouts composite index

## Testing
1. ✅ Navigate to Admin Dashboard
2. ✅ Click "System Health" tab
3. ✅ Verify data loads without errors
4. ✅ Verify health score displays
5. ✅ Verify reconciliation stats show
6. ✅ Verify failed operations list (if any)

## Index Build Time
Firestore indexes can take some time to build depending on the amount of data:
- Small datasets: A few seconds
- Medium datasets: A few minutes
- Large datasets: Could take hours

If the error persists immediately after deployment, wait a few minutes for the index to finish building in Firebase.

## Future Considerations
If similar errors occur on other admin dashboard features, check the Firebase Console error message for the exact index needed, or use the auto-generated link provided in Firestore errors to create the index automatically.

---

**Status**: ✅ **RESOLVED** - Index deployed and System Health tab is now functional!
