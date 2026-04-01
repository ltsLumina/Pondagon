enum EHostSessionResult
{
	Success,
	Failed,
};

enum EFindSessionResult
{
	Success,
	NotFound,
	Failed,
};

event void FOnHostSession(EHostSessionResult Result);
event void FOnFindSessionsStart();
event void FOnFindSessionsComplete(EFindSessionResult Result);

class UPondGameInstance : UGameInstance
{

};