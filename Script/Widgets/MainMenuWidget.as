class UMainMenuWidget : UPondWidgetBase
{
    UPROPERTY(BindWidget)
    UImage SteamAvatarImage;

    UPROPERTY(BindWidget)
    UTextBlock SteamUsernameLabel;
    
    UFUNCTION(BlueprintPure)
    bool HasSteamConnection()
    {
        return AdvancedSessions::HasOnlineSubsystem(n"STEAM");
    }

    UFUNCTION(BlueprintEvent)
    void InitSteam(APlayerController Controller)
    {}
}