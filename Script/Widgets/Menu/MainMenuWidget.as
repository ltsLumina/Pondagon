class UMainMenuWidget : UPondWidgetBase
{
    UPROPERTY(BindWidget)
    UImage SteamAvatarImage;

    UPROPERTY(BindWidget)
    UTextBlock SteamUsernameLabel;

    /**
     * Overriden in BP due to lack of AdvancedSessionsSteam support in AS.
     * Do not override this in AS!
     */
    UFUNCTION(BlueprintEvent)
    void InitSteam(APlayerController Controller)
    {}
}