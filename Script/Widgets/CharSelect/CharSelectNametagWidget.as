class UCharSelectNametagWidget : UPondWidgetBase
{
    UPROPERTY(BindWidget)
    UTextBlock PlayerLabel;

    UPROPERTY(BindWidget)
    UTextBlock HeroLabel;
    
    UPROPERTY(Category = "Nametag")
    FString PlayerName;

    UPROPERTY(Category = "Nametag")
    FString HeroName;

    UFUNCTION(BlueprintOverride)
    void Tick(FGeometry MyGeometry, float InDeltaTime)
    {
        PlayerLabel.SetText(FText::FromString(PlayerName));
        HeroLabel.SetText(FText::FromString(HeroName));
    }
}