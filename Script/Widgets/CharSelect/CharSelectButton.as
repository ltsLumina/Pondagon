class UCharSelectButton : UPondWidgetBase
{
    UPROPERTY(BindWidget)
    UButton HeroButton;

    UPROPERTY(Category = "Hero")
    FString HeroName;

    UFUNCTION(BlueprintOverride)
    void Construct()
    {
        HeroButton.OnClicked.AddUFunction(this, n"OnClicked");
    }

    UFUNCTION(NotBlueprintCallable)
    private void OnClicked()
    {
        auto PC = Cast<APondMenuController>(GetOwningPlayer());
        PC.SetHero(HeroName);
    }
}