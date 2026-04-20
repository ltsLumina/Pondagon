class UEnemyActorMenuExtension : UScriptActorMenuExtension
{
	default SupportedClasses.Add(AScriptEnemyBase);

	
}

/*
class UExampleActorMenuExtension : UScriptActorMenuExtension
{
	// Specify one or more classes for which the menu options show 
	default SupportedClasses.Add(AActor);

	// Every function with the CallInEditor specifier will become a context menu option
	UFUNCTION(CallInEditor)
	void ExampleActorMenuExtension()
	{
	}

	// The function's Category will be used to create sub-menus
	UFUNCTION(CallInEditor, Category = "Example Category")
	void ExampleOptionInSubCategory()
	{
	}

	// Custom icons can be specified with the `EditorIcon` meta tag:
	UFUNCTION(CallInEditor, Category = "Example Category", Meta = (EditorIcon = "Icons.Link"))
	void ExampleOptionWithIcon()
	{
	}

	// If the function takes an actor parameter, it will be called once for every selected actor
	UFUNCTION(CallInEditor, Category = "Example Category")
	void CalledForEverySelectedActor(AActor SelectedActor)
	{
		Print(f"Actor {SelectedActor} is selected");
	}

	// If the function has any other parameters, a dialog popup will be shown prompting for values
	UFUNCTION(CallInEditor, Category = "Example Category")
	void OpensPromptForParameters(AActor SelectedActor, bool bCheckboxParameter = true, FVector VectorParameter = FVector::ZeroVector)
	{
	}

	// The ActionIsVisible meta tag can show/hide an option based on conditions
	UFUNCTION(CallInEditor, Category = "Example Category", Meta = (ActionIsVisible = "Example_IsVisible"))
	void ExampleConditionalOption()
	{
	}

	UFUNCTION()
	bool Example_IsVisible()
	{
		return true;
	}

	// The ActionCanExecute meta tag determines whether the option is clickable or whether it is grayed out
	UFUNCTION(CallInEditor, Category = "Example Category", Meta = (ActionCanExecute = "Example_CanExecute"))
	void ExampleGrayedOutOption()
	{
	}

	UFUNCTION()
	bool Example_CanExecute()
	{
		return false;
	}

	/**
	 * We can use ActionType 'Check' and the ActionIsChecked meta tag to create an option with a checkmark
	 * Available ActionTypes are 'Button', 'ToggleButton', 'RadioButton', 'Check', 'CollapsedButton'
	 * Not every action type will be applicable to every type of menu/toolbar.
	 */
    /*
	UFUNCTION(CallInEditor, Category = "Example Category", Meta = (ActionType = "Check", ActionIsChecked = "Example_IsChecked"))
	void ExampleCheckboxOption()
	{
        
	}

	UFUNCTION()
	bool Example_IsChecked()
	{
		AActor SelectedActor = GetSelectedActor();
		if (SelectedActor != nullptr && !SelectedActor.IsHidden())
			return true;	
		return false;
	}
}