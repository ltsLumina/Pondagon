#if EDITOR
namespace BlueprintValidation
{
	/**
	 * Returns the generated blueprint asset from a given asset.
	 * This reference can cast to the appropriate class to access its properties.
	 * Not to be confused with Editor::GetBlueprintAsset, which returns the UBlueprint object, which does not have the properties of the blueprint class.
	 */
	UFUNCTION(Category = "Validation", Meta = (WorldContext = "InAsset"))
	const UObject GetBlueprint(UObject InAsset)
	{
		if (!InAsset.IsA(AActor)) return nullptr;
		
		auto Blueprint = Editor::GetBlueprintAsset(InAsset);

		TArray<FSubobjectDataHandle> SubobjectData;
		Subsystem::GetEngineSubsystem(USubobjectDataSubsystem).GatherSubobjectDataForBlueprint(Blueprint, SubobjectData);

		FSubobjectData Data;
		if (SubobjectData.IsValidIndex(0)) SubobjectData::GetData(SubobjectData[0], Data);
		else return nullptr;
		
		auto BlueprintAsset = SubobjectData::GetObjectForBlueprint(Data, Blueprint);

		return BlueprintAsset;
	}

	UFUNCTION(Category = "Validation", Meta = (WorldContext = "InAsset"))
	const UObject GetBlueprintGeneratedClass(UObject InAsset)
	{
		return Editor::GetBlueprintAsset(InAsset).GeneratedClass();
	}

	UFUNCTION(Category = "Validation", Meta = (WorldContext = "InAsset"))
	const UObject GetBlueprintCDO(UObject InAsset)
	{
		return Editor::GetBlueprintAsset(InAsset).GeneratedClass().GetDefaultObject();
	}

	/**
	 * Gathers all components from a blueprint asset.
	 * @param InAsset The blueprint asset to gather components from.
	 * @param Components The array to store the gathered components.
	 * @return True if components were found, false otherwise.
	 */
	UFUNCTION(Category = "Validation", Meta = (WorldContext = "InAsset"))
	bool GetBlueprintComponents(UObject InAsset, TArray<UObject>&out Components)
	{
		auto Blueprint = Editor::GetBlueprintAsset(InAsset);
		TArray<FSubobjectDataHandle> SubobjectData;
		Subsystem::GetEngineSubsystem(USubobjectDataSubsystem).GatherSubobjectDataForBlueprint(Blueprint, SubobjectData);
		for (auto& Component : SubobjectData)
		{
			FSubobjectData Data;
			SubobjectData::GetData(Component, Data);

			//Components.Add(SubobjectData::GetAssociatedObject(Data));
			throw("DEPRECATED: THIS FUNCTION NO LONGER WORKS DUE TO 5.7+ API UPDATES.");
		}

		return Components.Num() > 0;
	}

	UFUNCTION(Category = "Validation", Meta = (WorldContext = "InAsset"))
	UObject GetBlueprintComponent(UObject InAsset, UClass ComponentClass)
	{
		TArray<UObject> Components;
		if (GetBlueprintComponents(InAsset, Components))
		{
			for (int i = 0; i < Components.Num(); i++)
			{
				if (Components[i].IsA(ComponentClass))
				{
					return Components[i];
				}
			}
		}

		return nullptr;
	}
}

UCLASS(Abstract)
class UPondValidatorBase : UEditorValidatorBase
{
	UPROPERTY(Category = "Validation")
	TArray<TSubclassOf<UObject>> ValidatedClasses;
	default ValidatedClasses.Empty();

	UPROPERTY(Category = "Validation")
	bool ValidateBlueprint = true;

	UPROPERTY(Category = "Validation", BlueprintReadOnly, Meta = (Multiline))
	FText ValidationMessage = FText::FromString("Please provide a validation message.");

	UFUNCTION(BlueprintOverride)
	bool CanValidate(EDataValidationUsecase InUsecase) const
	{
		return true;
	}

	UFUNCTION(BlueprintOverride)
	bool CanValidateAsset(UObject InAsset) const
	{
		auto Blueprint = Editor::GetBlueprintAsset(InAsset);
		bool IsBlueprint = Blueprint != nullptr;
		UClass GeneratedBlueprint = IsBlueprint ? Editor::GetBlueprintAsset(InAsset).GeneratedClass : nullptr;

		for (auto& ValidatedClass : ValidatedClasses)
		{
			if (InAsset.IsA(ValidatedClass) || (ValidateBlueprint && IsBlueprint && GeneratedBlueprint.IsChildOf(ValidatedClass)))
			{
				return true;
			}
		}
		return false;
	}
}

class UEntityDefinitionValidator : UPondValidatorBase
{
	default ValidatedClasses.Add(UEntityDefinition);

	UFUNCTION(BlueprintOverride)
	EDataValidationResult ValidateLoadedAsset(UObject InAsset)
	{
		auto Def = Cast<UEntityDefinition>(InAsset);
		if (Def.StartingData.IsEmpty())
		{
			AssetFails(InAsset, FText::FromString("StartingData is empty!"));
			return EDataValidationResult::Invalid;
		}

		for (auto& Data : Def.StartingData)
		{
			if (Data.Key == nullptr || Data.Value == nullptr)
			{
				AssetFails(InAsset, FText::FromString("StartingData has a null table!"));
				return EDataValidationResult::Invalid;
			}
		}

        AssetPasses(InAsset);
		return EDataValidationResult::Valid;
	}
}

#endif