class APondGameState : AGameState
{

};

namespace Pond
{
    UFUNCTION(BlueprintPure)
    APondGameState GetPondGameStateBase()
    {
        return Cast<APondGameState>(Gameplay::GetGameState());
    }
}