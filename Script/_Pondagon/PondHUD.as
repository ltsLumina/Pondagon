class APondHUD : AAbilitySystemDebugHUD
{
    default bShowHUD = true;
    
    UPROPERTY(Category = "Material")
    UMaterialInterface SteamMaterial;

    UPROPERTY(Category = "Material")
    UMaterialInterface ClientMaterial;
    
	UFUNCTION(BlueprintOverride)
	void DrawHUD(int SizeX, int SizeY)
	{
        if (!IsValid(OwningPlayerController.PlayerState)) return;
        auto PS = OwningPlayerController.PlayerState;

        FString Msg;
        FString PlayerName;
        float PingMS;
        bool AuthorityStr = OwningPlayerController.HasAuthority();
        int ID;
        FString LocalRoleStr = f"{OwningPlayerController.LocalRole:n}";
        LocalRoleStr = LocalRoleStr.RightChop(5);
        FString RemoteRoleStr = f"{OwningPlayerController.RemoteRole:n}";
        RemoteRoleStr = RemoteRoleStr.RightChop(5);

        AdvancedSessions::GetPlayerName(OwningPlayerController, PlayerName);
        PingMS = PS.PingInMilliseconds;
        ID = Gameplay::GetGameState().PlayerArray.FindIndex(PS);
        
        Msg = f"{PlayerName}\nClient ID: {ID}\nPing: {PingMS:.0}ms\nAuthority: {AuthorityStr}";
        /*\nLocalRole: {LocalRoleStr}\nRemoteRole: {RemoteRoleStr}";*/
        DrawText(Msg, FLinearColor::DPink, 5, (SizeY - 65));

        DrawMaterialSimple(AdvancedSessions::HasSteamConnection() ? SteamMaterial : ClientMaterial, 0, SizeY - 125, 64, 64);
	}
}