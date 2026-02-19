import { BidTier, CoatingSystem, SurfaceCondition } from '@prisma/client';

export type PricingSettings = {
  laborRate: number;
  overheadRate: number;
  defaultMarkup: number;
  defaultMargin: number;
  taxRate: number;
  mobilizationFee: number;
  minimumJobPrice: number;
  wasteFactorStd: number;
  wasteFactorCpx: number;
};

export type PricingInputItem = {
  label: string;
  sqFt: number;
  coverageRate: number;
  costPerUnit: number;
  numCoats: number;
};

export type PricingInput = {
  totalSqFt: number;
  materialItems: PricingInputItem[];
  estimatedHours: number;
  crewCount: number;
  tier: BidTier;
  coatingSystem?: CoatingSystem | null;
  surfaceCondition?: SurfaceCondition | null;
  prepComplexity?: 'LIGHT' | 'STANDARD' | 'HEAVY';
  accessDifficulty?: 'EASY' | 'NORMAL' | 'DIFFICULT';
  isComplexLayout?: boolean;
};

export type TieredPricing = {
  tier: BidTier;
  subtotal: number;
  markup: number;
  taxAmount: number;
  totalPrice: number;
  profitMargin: number;
};

const TIER_MARKUP_ADDER: Record<BidTier, number> = { GOOD: 0, BETTER: 0.05, BEST: 0.1 };

function percentage(value: number): number {
  return value > 1 ? value / 100 : value;
}

function getConditionMultiplier(surfaceCondition?: SurfaceCondition | null): number {
  if (surfaceCondition === 'POOR') return 1.35;
  if (surfaceCondition === 'FAIR') return 1.2;
  if (surfaceCondition === 'GOOD') return 1.05;
  return 1;
}

function getCoatingMultiplier(coatingSystem?: CoatingSystem | null): number {
  if (!coatingSystem) return 1;
  if (coatingSystem === 'FULL_METALLIC') return 1.35;
  if (coatingSystem === 'COMMERCIAL_GRADE') return 1.25;
  if (coatingSystem === 'POLYASPARTIC') return 1.2;
  if (coatingSystem === 'QUARTZ') return 1.15;
  return 1;
}

function getPrepMultiplier(prepComplexity?: 'LIGHT' | 'STANDARD' | 'HEAVY'): number {
  if (prepComplexity === 'HEAVY') return 1.25;
  if (prepComplexity === 'LIGHT') return 0.9;
  return 1;
}

function getAccessMultiplier(accessDifficulty?: 'EASY' | 'NORMAL' | 'DIFFICULT'): number {
  if (accessDifficulty === 'DIFFICULT') return 1.2;
  if (accessDifficulty === 'EASY') return 0.95;
  return 1;
}

export function computeTieredPricing(input: PricingInput, settings: PricingSettings) {
  const wasteFactorUsed = input.isComplexLayout ? settings.wasteFactorCpx : settings.wasteFactorStd;
  const conditionMultiplier = getConditionMultiplier(input.surfaceCondition);
  const coatingMultiplier = getCoatingMultiplier(input.coatingSystem);
  const prepMultiplier = getPrepMultiplier(input.prepComplexity);
  const accessMultiplier = getAccessMultiplier(input.accessDifficulty);

  const materialCost =
    input.materialItems.reduce((sum, item) => {
      const units = (item.sqFt / item.coverageRate) * item.numCoats;
      return sum + units * item.costPerUnit;
    }, 0) *
    (1 + wasteFactorUsed);

  const adjustedHours = input.estimatedHours * conditionMultiplier * coatingMultiplier * prepMultiplier * accessMultiplier;
  const laborCost = adjustedHours * settings.laborRate * Math.max(1, input.crewCount);
  const overheadCost = (materialCost + laborCost) * percentage(settings.overheadRate);
  const baseSubtotal = materialCost + laborCost + overheadCost + settings.mobilizationFee;

  const minimumAppliedSubtotal = Math.max(baseSubtotal, settings.minimumJobPrice);
  const taxRate = percentage(settings.taxRate);
  const baseMarkup = percentage(settings.defaultMarkup);

  const options: TieredPricing[] = (['GOOD', 'BETTER', 'BEST'] as BidTier[]).map((tier) => {
    const markupRate = baseMarkup + TIER_MARKUP_ADDER[tier];
    const markup = minimumAppliedSubtotal * markupRate;
    const taxedBase = minimumAppliedSubtotal + markup;
    const taxAmount = taxedBase * taxRate;
    const totalPrice = taxedBase + taxAmount;
    const profitMargin = totalPrice === 0 ? 0 : markup / totalPrice;

    return {
      tier,
      subtotal: Number(minimumAppliedSubtotal.toFixed(2)),
      markup: Number(markup.toFixed(2)),
      taxAmount: Number(taxAmount.toFixed(2)),
      totalPrice: Number(totalPrice.toFixed(2)),
      profitMargin: Number(profitMargin.toFixed(4)),
    };
  });

  const selectedTier = options.find((option) => option.tier === input.tier) ?? options[1];

  const shoppingList = input.materialItems.map((item) => {
    const quantity = ((item.sqFt / item.coverageRate) * item.numCoats) * (1 + wasteFactorUsed);
    return { label: item.label, quantity: Number(quantity.toFixed(2)), unit: 'unit' };
  });

  return {
    selectedTier,
    options,
    materialCost: Number(materialCost.toFixed(2)),
    laborCost: Number(laborCost.toFixed(2)),
    overheadCost: Number(overheadCost.toFixed(2)),
    wasteFactorUsed,
    shoppingList,
  };
}
