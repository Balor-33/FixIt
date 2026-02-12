Summary: Image recognition integration using Google ML Kit (on-device image labeling).

Changes made:
- Added structured image metadata on issues (`images` field with {url, labels}) in `lib/models/issue_model.dart`.
- Report screen now analyzes images before upload and saves labels alongside URLs in the issue document (`lib/screens/report_issue_screen.dart`).
- iOS permission strings added to `ios/Runner/Info.plist` (camera + photo library).
- Firebase security rules added:
  - `firestore.rules` — restrict issue creation to authenticated users; only issue owner may update.
  - `storage.rules` — restrict writes to `issues/{userId}/{issueId}/...` to the authenticated owner; reads allowed for authenticated users.
- Added references to the rules in `firebase.json`.

Files added:
- `firestore.rules`
- `storage.rules`
- `docs/image_recognition_integration.md`

How it works:
1. User picks or takes a photo in `ReportIssueScreen` using `ImagePickerWidget`.
2. `ImageRecognitionService` analyzes the image using ML Kit and returns labels (on-device).
3. The app uploads the image to `Firebase Storage` into `issues/{userId}/{issueId}/{filename}`.
4. The app stores an `images` array on the `issue` document in Firestore containing objects `{url: string, labels: [{label, confidence}]}`.

Notes & next steps:
- This uses on-device ML Kit image labeling by default (no network cost).
- For domain-specific labels, train a custom TensorFlow Lite model and integrate with `tflite_flutter`.
- Deploy `firestore.rules` and `storage.rules` using `firebase deploy --only firestore,storage` (ensure Firebase CLI is configured).

If you want, I can now also:
- Add saving a top-level `aiSuggestedCategory` field on the issue (useful for professional filtering).
- Add an admin rule for professionals to read/update `assignedProfessionalId` only via backend functions.
- Add unit tests validating `ImageRecognitionService` parsing logic.

