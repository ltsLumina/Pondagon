#include "BlueprintExceptionLibrary.h"
#include "HAL/PlatformStackWalk.h"
#include "Misc/AssertionMacros.h"

FString UBlueprintExceptionLibrary::GetFormattedCallStack()
{
	FString ScriptStack = FFrame::GetScriptCallstack();
	ScriptStack.ReplaceInline(TEXT("/Game/"), TEXT(""));

	// Remove everything before the first triple-hyphen '---' (inclusive)
	{
		int32 SepIndex = ScriptStack.Find(TEXT("---"), ESearchCase::IgnoreCase, ESearchDir::FromStart);
		if (SepIndex != INDEX_NONE)
		{
			// Keep everything after the '---'
			ScriptStack = ScriptStack.Mid(SepIndex + 3);
			// Trim any leading whitespace/newlines that may follow
			ScriptStack = ScriptStack.TrimStart();
		}
	}

	// Remove any code between two periods, e.g., .BP_FishCharacter.BP_FishCharacter_C.
	{
		FString Result;
		int32 Len = ScriptStack.Len();
		int32 i = 0;
		while (i < Len)
		{
			TCHAR C = ScriptStack[i];
			if (C == TEXT('.'))
			{
				// Find next dot
				int32 NextDot = INDEX_NONE;
				for (int32 k = i + 1; k < Len; ++k)
				{
					if (ScriptStack[k] == TEXT('.'))
					{
						NextDot = k;
						break;
					}
				}

				// If there's text between two dots, collapse the whole segment to a single dot
				if (NextDot != INDEX_NONE && NextDot > i + 1)
				{
					Result += TEXT('.');
					i = NextDot + 1;
					continue;
				}
				else
				{
					// Either consecutive dots or no closing dot: keep the dot as-is
					Result += TEXT('.');
					i++;
					continue;
				}
			}

			// Regular character: append
			Result.AppendChar(C);
			i++;
		}

		ScriptStack = MoveTemp(Result);
		
		// Remove any trailing newlines
		ScriptStack = ScriptStack.TrimEnd();
		ScriptStack.ReplaceInline(TEXT("\r\n"), TEXT("\n"));
	}

	return ScriptStack;
}

FString UBlueprintExceptionLibrary::GetCallStack()
{
	FString ScriptStack = FFrame::GetScriptCallstack();
	return ScriptStack;
}
