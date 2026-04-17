UCLASS(Meta=(PrioritizeCategories="Entity | Details"))
class UHeroDefinition : UEntityDefinition
{
    UPROPERTY(Category = "Entity | GAS")
    UWeaponDefinition WeaponDefinition;
}