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

class UExampleAssetMenuExtension : UScriptAssetMenuExtension
{
	default SupportedClasses.Add(UDataTable);

	/**
	 * Adds a GameplayAttribute to a DataTable.
	 * Alternative to writing it out manually, potentially with typos or other mistakes.
	 */
	UFUNCTION(CallInEditor, Category = "Attributes", Meta = (EditorIcon = "Icons.Plus", AdvancedDisplay = "Row"))
	void AddAttribute(UDataTable SelectedTable, FGameplayAttribute Attribute, FAttributeMetaData Row)
	{
		if (GetSelectedAssets().Num() > 1)
		{
			if (FMessageDialog::Open(EAppMsgCategory::Error, EAppMsgType::Ok, FText::FromString("Only one (1) DataTable can be modified at a time!")) == EAppReturnType::Ok)
			{
				UAssetEditorSubsystem::Get().CloseAllEditorsForAsset(SelectedTable);
				return;
			}
		}

		SelectedTable.Modify();

		FString ClassName = f"{Attribute.AttributeSetClass}";
		ClassName.RemoveFromStart("{ ");
		ClassName.RemoveFromEnd(" (UASClass) }");
		FString FooBar = f"{ClassName}.{Attribute.AttributeName}";

		FName BarBar = FName(FooBar);
		SelectedTable.AddRow(BarBar, Row);

		UAssetEditorSubsystem::Get().CloseAllEditorsForAsset(SelectedTable);
		TArray<UObject> Foo;
		Foo.Add(SelectedTable);
		UAssetEditorSubsystem::Get().OpenEditorForAssets(Foo);
	}

	UFUNCTION(CallInEditor, Category = "Attributes", Meta = (EditorIcon = "Icons.Plus"))
	void UpdateAttribute(UDataTable SelectedTable, FGameplayAttribute Attribute, bool ApplyToMaxAttribute, float Value)
	{
		SelectedTable.Modify();

		FString ClassName = f"{Attribute.AttributeSetClass}";
		ClassName.RemoveFromStart("{ ");
		ClassName.RemoveFromEnd(" (UASClass) }");
		FName RowName = FName(f"{ClassName}.{Attribute.AttributeName}");
		FName MaxRowName = FName(f"{ClassName}.Max{Attribute.AttributeName}");

		FAttributeMetaData ExistingAttributeRow;
		bool FoundAttr = SelectedTable.FindRow(RowName, ExistingAttributeRow);
		if (FoundAttr)
		{
			ExistingAttributeRow.BaseValue = Value;

			SelectedTable.RemoveRow(RowName);
			SelectedTable.AddRow(RowName, ExistingAttributeRow);
		}
		else
		{
			FAttributeMetaData NewRow;
			NewRow.BaseValue = Value;

			// Upsert behavior: create if missing
			SelectedTable.AddRow(RowName, NewRow);
			FMessageDialog::Open(EAppMsgType::Ok, FText::FromString(f"Couldn't find an entry with row name: {RowName}"));
		}

		FAttributeMetaData ExistingMaxAttributeRow;
		bool FoundMax = SelectedTable.FindRow(MaxRowName, ExistingMaxAttributeRow);
		if (FoundMax)
		{
			if (ExistingAttributeRow.BaseValue > ExistingMaxAttributeRow.BaseValue)
			{
				ExistingMaxAttributeRow.BaseValue = Value;

				SelectedTable.RemoveRow(MaxRowName);
				SelectedTable.AddRow(MaxRowName, ExistingMaxAttributeRow);

				FMessageDialog::Open(EAppMsgType::Ok, FText::FromString(f"Max Attribute was clamped!\nMax cannot be smaller than its base counterpart.\n\nNew Value: {Value}"));
			}
		}

		if (ApplyToMaxAttribute)
		{
			if (FoundMax)
			{
				ExistingMaxAttributeRow.BaseValue = Value;

				SelectedTable.RemoveRow(MaxRowName);
				SelectedTable.AddRow(MaxRowName, ExistingMaxAttributeRow);
			}
			else
			{
				FAttributeMetaData NewRow;
				NewRow.BaseValue = Value;

				// Upsert behavior: create if missing
				SelectedTable.AddRow(RowName, NewRow);
				FMessageDialog::Open(EAppMsgType::Ok, FText::FromString(f"Couldn't find an entry with row name: {MaxRowName}"));
			}
		}

		if (FoundAttr || FoundMax)
		{
			UAssetEditorSubsystem::Get().CloseAllEditorsForAsset(SelectedTable);
			TArray<UObject> Assets;
			Assets.Add(SelectedTable);
			UAssetEditorSubsystem::Get().OpenEditorForAssets(Assets);
		}
	}
}

/*
class UDataTableExtension : UScriptEditorMenuExtension
{
	// Add to the extension point at the end of the level editor toolbar:
	//default ExtensionPoint = n"AssetEditorToolbar.CommonActions";
	default ExtensionPoint = n"AssetEditorToolbar.CommonActions";

	/**
	 * Opens the GDD.
	 */

/*
UFUNCTION(CallInEditor, DisplayName = "Add Attribute", Meta = (EditorIcon = "Icons.Plus", EditorButtonStyle = "CalloutToolbar"))
void A_AddAttribute(FGameplayAttribute Foo, int Bar = 1)
{
   auto SelectedAsset = EditorUtility::GetSelectedAssets()[0];
   SelectedAsset.MarkPackageDirty();
   auto AsDT = Cast<UDataTable>(SelectedAsset);
   FAttributeMetaData Row;

   for (int i = 0; i < Bar; i++)
   {
	   FString ClassName = f"{Foo.AttributeSetClass}";
	   ClassName.RemoveFromStart("{ ");
	   ClassName.RemoveFromEnd(" (UASClass) }");
	   FString FooBar = f"{ClassName}.{Foo.AttributeName}";

	   FName BarBar = FName(FooBar);
	   AsDT.AddRow(BarBar, Row);
   }
   SelectedAsset.MarkPackageDirty();
   UToolMenus::Get().RefreshMenuWidget(n"AssetEditorToolbar.CommonActions");
}
};
*/
#endif
