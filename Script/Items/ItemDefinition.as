class UItemDefinition : UPrimaryDataAsset
{
    UPROPERTY(Category = "Display")
    FText DisplayName;
    default DisplayName = FText::FromString(Class.GetFullName());

    UPROPERTY(Category = "Display", Meta=(Multiline="true"))
    FText Description;

    UPROPERTY(Category = "Display")
    UTexture2D Icon;

    UPROPERTY(Category = "Data")
    int StackSize = 1;
}