import { PrismaClient, Plan } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

const EPOXY_MATERIALS = [
  // Water-based epoxies
  { name: 'ArmorSeal 1000 HS Water-Based Epoxy', brand: 'Sherwin-Williams', sku: 'SW-AS1000HS', category: 'Water-Based Epoxy', unit: 'gallon', costPerUnit: 89.99, coverageRate: 300, numCoats: 2, notes: 'High-solids, low VOC. Excellent adhesion on concrete.' },
  { name: 'Rust-Oleum EpoxyShield Water-Based', brand: 'Rust-Oleum', sku: 'RO-EPXYSHLD-WB', category: 'Water-Based Epoxy', unit: 'gallon', costPerUnit: 54.99, coverageRate: 250, numCoats: 2, notes: 'Residential garage floors. Easy cleanup.' },

  // Solvent-based epoxies
  { name: 'Stonclad GS Epoxy', brand: 'Stonhard', sku: 'SH-GS-100', category: 'Solvent-Based Epoxy', unit: 'kit', costPerUnit: 149.99, coverageRate: 200, numCoats: 2, notes: 'Industrial grade. Chemical resistant. 2-part kit (5-gal).' },
  { name: 'ArmorPoxy 2-Part Epoxy', brand: 'ArmorPoxy', sku: 'AP-2PT-EP', category: 'Solvent-Based Epoxy', unit: 'gallon', costPerUnit: 119.99, coverageRate: 225, numCoats: 2, notes: 'UV stable. Commercial and residential.' },

  // Polyaspartic
  { name: 'Penntek PolyAsptic PC-12', brand: 'Penntek', sku: 'PT-PC12', category: 'Polyaspartic', unit: 'gallon', costPerUnit: 179.99, coverageRate: 400, numCoats: 1, notes: 'Fast-cure polyaspartic topcoat. UV stable. Single coat.' },
  { name: 'GarageCoatings.com Polyaspartic', brand: 'GarageCoatings', sku: 'GC-POLY-1G', category: 'Polyaspartic', unit: 'gallon', costPerUnit: 159.99, coverageRate: 350, numCoats: 1, notes: 'Aliphatic polyaspartic. High gloss finish.' },

  // Decorative flake
  { name: 'Vinyl Color Chip Flakes — Mixed Blend', brand: 'Designers Choice', sku: 'DC-FLAKE-MIX', category: 'Decorative Flake', unit: 'pound', costPerUnit: 12.99, coverageRate: 100, numCoats: 1, notes: 'Full broadcast: ~0.5 lb/sqFt. Partial: ~0.25 lb/sqFt.' },
  { name: 'Mica Flake Chips', brand: 'Richlite', sku: 'RL-MICA-CHIP', category: 'Decorative Flake', unit: 'pound', costPerUnit: 18.99, coverageRate: 100, numCoats: 1, notes: 'Premium mica flakes for metallic effect.' },

  // Metallic epoxy
  { name: 'Leggari 1-Part Metallic Epoxy', brand: 'Leggari', sku: 'LG-MET-EP-1G', category: 'Metallic Epoxy', unit: 'gallon', costPerUnit: 139.99, coverageRate: 60, numCoats: 1, notes: 'Self-leveling metallic pigment system. Works with base coat.' },
  { name: 'Rust-Oleum Metallic Epoxy Kit', brand: 'Rust-Oleum', sku: 'RO-MET-EP-KIT', category: 'Metallic Epoxy', unit: 'kit', costPerUnit: 249.99, coverageRate: 250, numCoats: 1, notes: 'Complete 2-car garage kit. Includes base + metallic layer + topcoat.' },

  // Quartz / broadcast aggregate
  { name: 'Silica Quartz Sand #30', brand: 'U.S. Silica', sku: 'USS-Q30', category: 'Quartz Aggregate', unit: 'pound', costPerUnit: 0.89, coverageRate: 50, numCoats: 1, notes: 'Anti-slip aggregate. Broadcast into wet epoxy.' },
  { name: 'Colored Quartz Broadcast', brand: 'Prismo', sku: 'PR-CQ-BCAST', category: 'Quartz Aggregate', unit: 'pound', costPerUnit: 2.49, coverageRate: 50, numCoats: 1, notes: 'Colored quartz for decorative terrazzo-style finishes.' },

  // Primers
  { name: 'Penetrating Epoxy Primer', brand: "Rust-Oleum", sku: 'RO-PEP-1G', category: 'Primer', unit: 'gallon', costPerUnit: 49.99, coverageRate: 200, numCoats: 1, notes: 'Penetrating primer for porous or damaged concrete.' },
  { name: 'Moisture Vapor Barrier Primer', brand: 'Sikafloor', sku: 'SF-MVB-P', category: 'Primer', unit: 'gallon', costPerUnit: 79.99, coverageRate: 150, numCoats: 1, notes: 'Required for slabs with moisture vapor ≥8 lbs/1000 sqFt/day.' },

  // Topcoats
  { name: 'Sherwin-Williams Armorclad Urethane', brand: 'Sherwin-Williams', sku: 'SW-ARMORCLAD', category: 'Topcoat', unit: 'gallon', costPerUnit: 109.99, coverageRate: 350, numCoats: 1, notes: 'Aliphatic urethane. UV stable, scratch resistant clear coat.' },
  { name: 'Flat Matte Epoxy Topcoat', brand: 'Generic', sku: 'GEN-FMT-1G', category: 'Topcoat', unit: 'gallon', costPerUnit: 69.99, coverageRate: 300, numCoats: 1, notes: 'Matte finish clear coat.' },

  // Supplies / consumables
  { name: 'Concrete Crack Filler (epoxy injection)', brand: 'Sika', sku: 'SK-CRACKFIL', category: 'Supplies', unit: 'tube', costPerUnit: 14.99, coverageRate: 1, numCoats: 1, notes: 'For cracks up to 1/2 inch wide. 10 oz cartridge.' },
  { name: 'Non-Slip Additive (AlumOx)', brand: 'Rust-Oleum', sku: 'RO-NONSKID', category: 'Supplies', unit: 'packet', costPerUnit: 9.99, coverageRate: 200, numCoats: 1, notes: 'Aluminum oxide powder. Mix into topcoat for anti-slip.' },
];

const DEFAULT_TEMPLATES = [
  {
    name: 'Standard Residential Garage',
    type: 'BID',
    content: {
      executiveSummary: 'We are pleased to present this proposal for your epoxy flooring project. Our team of certified applicators will transform your garage floor into a durable, beautiful surface that will last for years to come.',
      scopeNotes: '• Diamond grind / shot blast surface preparation\n• Fill all cracks and expansion joints\n• Apply moisture vapor barrier primer if needed\n• Apply epoxy base coat\n• Full broadcast of decorative chips\n• Apply clear polyaspartic topcoat\n• 24-hour return to service\n• 5-year warranty on labor',
      paymentTerms: '50% deposit required to schedule. Remaining 50% due upon project completion.',
      warrantyText: 'EpoxyBidPro guarantees all labor for 5 years from project completion date. Material warranties as specified by manufacturer.',
    },
    isDefault: true,
  },
  {
    name: 'Commercial / Industrial Floor',
    type: 'BID',
    content: {
      executiveSummary: 'Professional-grade industrial epoxy system designed for heavy traffic, chemical exposure, and demanding commercial environments.',
      scopeNotes: '• Shotblast surface prep (ICRI CSP 3-4)\n• Moisture vapor testing and barrier if required\n• Apply primer coat\n• Apply 100%-solids epoxy base (2 coats)\n• Broadcast anti-slip aggregate as specified\n• Apply aliphatic urethane topcoat\n• Install perimeter cove base if specified\n• 3-day cure before heavy traffic',
      paymentTerms: 'Net 30 upon invoice. Or 50% at project start, 50% at completion.',
      warrantyText: '3-year labor warranty on commercial installations.',
    },
    isDefault: false,
  },
];

async function main() {
  console.log('🌱  Seeding database...');

  // ─── Create demo business + user ─────────────────────────────────────────────
  const passwordHash = await bcrypt.hash('Demo1234!', 12);

  const business = await prisma.business.upsert({
    where: { id: 'seed-business-001' },
    update: {},
    create: {
      id: 'seed-business-001',
      name: 'Demo Epoxy Co.',
      bidPrefix: 'BID',
      nextBidNum: 1001,
      nextInvoiceNum: 2001,
      laborRate: 3.50,    // $ per sqFt
      defaultMarkup: 25,  // 25%
      taxRate: 8.5,       // 8.5%
      primaryColor: '#1E3A5F',
      accentColor: '#F59E0B',
      users: {
        create: {
          email: 'demo@epoxyco.com',
          passwordHash,
          firstName: 'Alex',
          lastName: 'Demo',
          role: 'OWNER',
          plan: Plan.SOLO,
          isEmailVerified: true,
          trialEndsAt: new Date(Date.now() + 14 * 24 * 60 * 60 * 1000),
        },
      },
    },
  });

  console.log(`✅  Business: ${business.name}`);

  // ─── Seed materials into the demo business ───────────────────────────────────
  let materialCount = 0;
  for (const mat of EPOXY_MATERIALS) {
    await prisma.material.upsert({
      where: {
        // Unique on sku + businessId if we had that constraint; use name+businessId instead
        id: `mat-seed-${mat.sku.toLowerCase().replace(/[^a-z0-9]/g, '-')}`,
      },
      update: { costPerUnit: mat.costPerUnit },
      create: {
        id: `mat-seed-${mat.sku.toLowerCase().replace(/[^a-z0-9]/g, '-')}`,
        businessId: business.id,
        ...mat,
        isActive: true,
      },
    });
    materialCount++;
  }

  console.log(`✅  ${materialCount} epoxy materials seeded`);

  // ─── Seed default bid templates ──────────────────────────────────────────────
  const user = await prisma.user.findFirst({ where: { businessId: business.id } });
  if (user) {
    let templateCount = 0;
    for (const tmpl of DEFAULT_TEMPLATES) {
      await prisma.template.upsert({
        where: { id: `tmpl-seed-${tmpl.name.toLowerCase().replace(/\s+/g, '-').slice(0, 30)}` },
        update: {},
        create: {
          id: `tmpl-seed-${tmpl.name.toLowerCase().replace(/\s+/g, '-').slice(0, 30)}`,
          businessId: business.id,
          createdById: user.id,
          ...tmpl,
        },
      });
      templateCount++;
    }
    console.log(`✅  ${templateCount} bid templates seeded`);
  }

  console.log('🎉  Seeding complete!');
}

main()
  .catch((e) => {
    console.error('❌  Seed failed:', e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
