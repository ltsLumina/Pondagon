// Copyright 2024 Diversion Company, Inc. All Rights Reserved.

#pragma once

#include "Widgets/Notifications/SNotificationList.h"

struct FDiversionNotification
{
	FDiversionNotification(const FText& Message, const TArray<FNotificationButtonInfo>& Button,
		SNotificationItem::ECompletionState Type, bool bShowDismissButton = true)
		: Message(Message),
		  Button(Button),
		  Type(Type),
		  bShowDismissButton(bShowDismissButton)
	{
	}
	
	FText Message;
	TArray<FNotificationButtonInfo> Button;
	SNotificationItem::ECompletionState Type;
	bool bShowDismissButton;
};


class COMMON_API FDiversionNotificationManager
{
public:
	typedef int32 FNotificationId;  
	FNotificationId ShowNotification(const FDiversionNotification& InDiversionNotificationInfo);
	
	void DismissNotification(FNotificationId NotificationId);
	
private:

	struct FOpenNotification
	{
		FNotificationId NotificationId;
		TWeakPtr<class SNotificationItem> NotificationItem;
		const FText NotificationMessage;

		FOpenNotification(FNotificationId InNotificationId,
						  const TWeakPtr<class SNotificationItem>& InNotificationItem,
						  const FText InNotificationMessage)
			: NotificationId(InNotificationId)
			, NotificationItem(InNotificationItem)
			, NotificationMessage( InNotificationMessage)
		{
		}
		FOpenNotification() : NotificationId(INDEX_NONE) {}
	};
	// Notifications that wasn't actively dismissed
	TArray<FOpenNotification> OpenNotifications;
	FNotificationId NextNotificationId = 0;
};
