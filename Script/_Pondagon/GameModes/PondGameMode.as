class APondGameMode : AGameMode
{
    UFUNCTION(BlueprintOverride)
    void OnPostLogin(APlayerController NewPlayer)
    {
        Widget::SetInputMode_GameOnly(NewPlayer, false);
        NewPlayer.bShowMouseCursor = false;
    }
};