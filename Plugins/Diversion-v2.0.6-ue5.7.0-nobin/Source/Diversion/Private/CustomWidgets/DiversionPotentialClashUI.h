// Copyright 2024 Diversion Company, Inc. All Rights Reserved.

#pragma once

#include "Widgets/SCompoundWidget.h"

class SPotentialClashIndicator : public SCompoundWidget
{
public:
	SLATE_BEGIN_ARGS(SPotentialClashIndicator) {}
		SLATE_ARGUMENT(FString, AssetPath)
	SLATE_END_ARGS();

	/**
	 * Construct this widget.
	 * @param InArgs Slate arguments
	 */
	void Construct(const FArguments& InArgs);

	/** Caches the indicator brushes for access. */
	static void CacheIndicatorBrush();

	virtual ~SPotentialClashIndicator() = default;

private:

	static bool IsAssetHasPotentialClashes(FString Path);

	EVisibility GetVisibility() const
	{
		return IsAssetHasPotentialClashes(AssetPath) ? EVisibility::Visible : EVisibility::Collapsed;
	}

	const FSlateBrush* GetImageBrush() const
	{
		return IsAssetHasPotentialClashes(AssetPath) ? PotentialClashIcon : nullptr;
	}

	static const FSlateBrush* PotentialClashIcon;

	/** Asset path for this indicator widget.*/
	FString AssetPath;
};


class SPotentialClashTooltip : public SCompoundWidget
{
public:
	SLATE_BEGIN_ARGS(SPotentialClashTooltip) {}
		SLATE_ARGUMENT(FString, AssetPath)
	SLATE_END_ARGS();

	/**
	 * Construct this widget.
	 * @param InArgs Slate arguments
	 */
	void Construct(const FArguments& InArgs);

	virtual ~SPotentialClashTooltip() = default;
private:

	static bool IsAssetHasPotentialClashes(FString Path);

	EVisibility GetVisibility() const
	{
		return IsAssetHasPotentialClashes(AssetPath) ? EVisibility::Visible : EVisibility::Collapsed;
	}

	FText GetTooltip() const;

	/** Asset path for this indicator widget.*/
	FString AssetPath;
};


