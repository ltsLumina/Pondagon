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
    
    UPROPERTY(Category = "Input | Actions")
	UInputAction MoveAction;

	UPROPERTY(Category = "Input | Actions")
	UInputAction ShootAction;

	UPROPERTY(Category = "Input | Actions")
	UInputAction ADS_Action;

    UPROPERTY(Category = "Input | Actions")
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
    }

    void SubscribeInputEvents()
    {
        auto Character = Gameplay::GetPlayerCharacter(0);
        auto GunComponent = UGunComponent::Get(Character);
        
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
};