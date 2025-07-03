# Fathom App Widget Functionality (Reserved for Future Release)

## Status
- The FathomWidgetsExtension (Widget Extension) is currently **deactivated** and excluded from all build schemes as of 2025-06-18.
- All widget-related code remains in the codebase, but is not compiled, embedded, or shipped in the app.
- This was done to reserve widget functionality for a future deployment while maintaining a minimum deployment target of 26.0 Beta.

## How to Re-enable Widgets
1. **Edit `project.pbxproj`:**
   - Uncomment all lines related to `FathomWidgetsExtension` in the `Fathom.xcodeproj/project.pbxproj` file. This includes the PBXNativeTarget block, dependencies, and references in build phases, products, and project targets.
   - Save the file and re-open the project in Xcode.
2. **Re-add Widget Target to Schemes:**
   - In Xcode, go to Product > Scheme > Manage Schemes and ensure `FathomWidgetsExtension` is checked for build and run as needed.
3. **Review Deployment Target:**
   - Ensure that the deployment target for the widget matches or exceeds the app’s minimum (26.0 Beta).
4. **Test Widget Functionality:**
   - Build and run on a device or simulator supporting iOS 17+ (26.0 Beta) to verify widget behavior.

## Notes
- No widget-related Info.plist keys or entitlements are present in the main app.
- All widget Swift files and assets remain in the `FathomWidgets/` directory.
- No code changes are needed in the main app unless new widget-related features are added in the future.

---
*For further assistance, consult the project history or contact the original developer who performed the deactivation (2025-06-18).*
