#if EDITOR
/**
 * Toolbars can also be extended. Each function will become its own toolbar button.
 */
class UExampleToolbarExtension : UScriptEditorMenuExtension
{
	// Add to the extension point at the end of the level editor toolbar:
	default ExtensionPoint = n"LevelEditor.LevelEditorToolBar.User";

	/**
     * Opens the GDD.
     */
	UFUNCTION(CallInEditor, DisplayName = "Open GDD", Meta = (EditorIcon = "Icons.Plus", EditorButtonStyle = "CalloutToolbar"))
	void A_OpenGDD()
	{
        System::LaunchURL("docs.google.com/document/d/1BaZ1sqJaKooWYqLl-sczmf8V-KfVYzTdcmXV3vAdRyM");
	}

	/**
	 * 
	 */
    UFUNCTION(CallInEditor, DisplayName = "GAS Docs", Meta = (EditorIcon = "Icons.Minus", EditorButtonStyle = "CalloutToolbar"))
	void B_OpenGASDocumentation()
	{
        System::LaunchURL("https://github.com/tranek/GASDocumentation");
	}
};
#endif
