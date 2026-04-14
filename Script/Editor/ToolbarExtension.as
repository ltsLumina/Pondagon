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
	UFUNCTION(CallInEditor, DisplayName = "GAS Docs", Meta = (EditorIcon = "Icons.Plus", EditorButtonStyle = "CalloutToolbar"))
	void B_OpenGASDocumentation()
	{
		System::LaunchURL("https://github.com/tranek/GASDocumentation");
	}

	/**
	 *
	 */
	UFUNCTION(CallInEditor, DisplayName = "AS Docs", Meta = (EditorIcon = "Icons.Plus", EditorButtonStyle = "CalloutToolbar"))
	void C_OpenAngelscriptDocs()
	{
		System::LaunchURL("https://angelscript.hazelight.se/");
	}
};

/**
 * Other editor menus can be extended with UScriptEditorMenuExtension.
 */
class UExampleEditorMenuExtension : UScriptEditorMenuExtension
{
	default ExtensionPoint = n"MainFrame.MainMenu";
	
	// The function's Category will be used to create sub-menus
	UFUNCTION(CallInEditor, Category = "Development | Open Map")
	void MenuMap()
	{
		switch (FMessageDialog::Open(EAppMsgType::YesNo, FText::FromString("Save current map?")))
		{
			case EAppReturnType::Yes:
			if (UEditorLoadingAndSavingUtils::SaveCurrentLevel())
			{
				UEditorLoadingAndSavingUtils::LoadMap("/Game/Pondagon/L_MainMenu.L_MainMenu");
			}
			else
			{
				if (FMessageDialog::Open(EAppMsgCategory::Error, EAppMsgType::Ok, FText::FromString("Failed to save current map!")) == EAppReturnType::Ok)
				{
					UEditorLoadingAndSavingUtils::LoadMap("/Game/Pondagon/L_MainMenu.L_MainMenu");
					break;
				}
			}
			break;

			case EAppReturnType::No:
			UEditorLoadingAndSavingUtils::LoadMap("/Game/Pondagon/L_MainMenu.L_MainMenu");
			break;

			default:
			break;
		}
	}

	UFUNCTION(CallInEditor, Category = "Development | Open Map")
	void GameMap()
	{
		switch (FMessageDialog::Open(EAppMsgType::YesNo, FText::FromString("Save current map?")))
		{
			case EAppReturnType::Yes:
			if (UEditorLoadingAndSavingUtils::SaveCurrentLevel())
			{
				UEditorLoadingAndSavingUtils::LoadMap("/Game/Pondagon/L_DefaultMap.L_DefaultMap");
			}
			else
			{
				if (FMessageDialog::Open(EAppMsgCategory::Error, EAppMsgType::Ok, FText::FromString("Failed to save current map!")) == EAppReturnType::Ok)
				{
					UEditorLoadingAndSavingUtils::LoadMap("/Game/Pondagon/L_DefaultMap.L_DefaultMap");
					break;
				}
			}
			break;

			case EAppReturnType::No:
			UEditorLoadingAndSavingUtils::LoadMap("/Game/Pondagon/L_DefaultMap.L_DefaultMap");
			break;

			default:
			break;
		}
	}
};

#endif
