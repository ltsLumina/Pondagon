class APondController : APlayerController
{
    UPROPERTY(Category = "Input | Mapping Context", DefaultComponent, NotVisible, BlueprintReadOnly)
	UEnhancedInputComponent InputComponent;
    
    UPROPERTY(Category = "Input | Mapping Context")
	UInputMappingContext IMC_Default;

    UPROPERTY(Category = "Input | Mapping Context")
	UInputMappingContext IMC_MouseLook;

    UPROPERTY(Category = "Input | Mapping Context")
	UInputMappingContext IMC_Weapons;
    
    UPROPERTY(Category = "Input | Actions | Movement")
	UInputAction MoveAction;

	UPROPERTY(Category = "Input | Actions | Movement")
	UInputAction JumpAction;

	UPROPERTY(Category = "Input | Actions | Guns")
	UInputAction CrouchAction;

	UPROPERTY(Category = "Input | Actions | Guns")
	UInputAction ShootAction;

	UPROPERTY(Category = "Input | Actions | Guns")
	UInputAction ADS_Action;

    UPROPERTY(Category = "Input | Actions | Guns")
	UInputAction ReloadAction;
    
    UFUNCTION(BlueprintOverride)
    void BeginPlay()
    {
        PushInputComponent(InputComponent);

		UEnhancedInputLocalPlayerSubsystem EnhancedInputSubsystem = UEnhancedInputLocalPlayerSubsystem::Get(this);
		EnhancedInputSubsystem.AddMappingContext(IMC_Default, 1, FModifyContextOptions());
        EnhancedInputSubsystem.AddMappingContext(IMC_MouseLook, 1, FModifyContextOptions());
        EnhancedInputSubsystem.AddMappingContext(IMC_Weapons, 0, FModifyContextOptions());

        SubscribeInputEvents();

		HandleMovementStates();
    }

    void SubscribeInputEvents()
    {
        auto GunComponent = UGunComponent::Get(ControlledPawn);
        
        // Shooting
		InputComponent.BindAction(ShootAction, ETriggerEvent::Triggered, FEnhancedInputActionHandlerDynamicSignature(GunComponent, n"Interim_Shoot"));

		// ADS (Aim Down Sights)
		InputComponent.BindAction(ADS_Action, ETriggerEvent::Started, FEnhancedInputActionHandlerDynamicSignature(GunComponent, n"StartADS"));
		InputComponent.BindAction(ADS_Action, ETriggerEvent::Canceled, FEnhancedInputActionHandlerDynamicSignature(GunComponent, n"CancelledADS"));
		InputComponent.BindAction(ADS_Action, ETriggerEvent::Triggered, FEnhancedInputActionHandlerDynamicSignature(GunComponent, n"TriggeredADS"));
		InputComponent.BindAction(ADS_Action, ETriggerEvent::Completed, FEnhancedInputActionHandlerDynamicSignature(GunComponent, n"EndADS"));

		// Reloading
		InputComponent.BindAction(ReloadAction, ETriggerEvent::Triggered, FEnhancedInputActionHandlerDynamicSignature(GunComponent, n"Interim_Reload"));
    }
	
	void HandleMovementStates()
	{
		APondHero Hero = Cast<APondHero>(ControlledPawn);
		InputComponent.BindAction(MoveAction, ETriggerEvent::Triggered, FEnhancedInputActionHandlerDynamicSignature(Hero, n"OnMove_Triggered"));
		InputComponent.BindAction(MoveAction, ETriggerEvent::Completed, FEnhancedInputActionHandlerDynamicSignature(Hero, n"OnMove_Completed"));
		InputComponent.BindAction(CrouchAction, ETriggerEvent::Triggered, FEnhancedInputActionHandlerDynamicSignature(Hero, n"OnCrouch_Triggered"));
		InputComponent.BindAction(CrouchAction, ETriggerEvent::Canceled, FEnhancedInputActionHandlerDynamicSignature(Hero, n"OnCrouch_Cancelled"));
		InputComponent.BindAction(CrouchAction, ETriggerEvent::Completed, FEnhancedInputActionHandlerDynamicSignature(Hero, n"OnCrouch_Completed"));
		InputComponent.BindAction(JumpAction, ETriggerEvent::Started, FEnhancedInputActionHandlerDynamicSignature(Hero, n"OnJump_Started"));
	}
};