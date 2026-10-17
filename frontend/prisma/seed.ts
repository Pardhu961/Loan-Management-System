import { PrismaClient } from '@prisma/client';
import { Pool } from 'pg';
import { PrismaPg } from '@prisma/adapter-pg';
import 'dotenv/config';

import {
  INITIAL_ROLES,
  INITIAL_BRANCHES,
  INITIAL_USERS,
  LOAN_PRODUCTS_CONFIG,
  INITIAL_APPROVAL_MATRIX_RULES,
} from '../src/config/systemTemplates';

const connectionString =
  process.env.DATABASE_URL ||
  `postgresql://${process.env.PGUSER || 'postgres'}:${process.env.PGPASSWORD || 'postgres'}@${process.env.PGHOST || 'localhost'}:${process.env.PGPORT || '5432'}/${process.env.PGDATABASE || 'loan_ms_db'}?schema=public`;

const pool = new Pool({ connectionString, max: 2, idleTimeoutMillis: 5000 });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

function parseDate(dateStr?: string | null): Date {
  if (!dateStr) return new Date();
  const parsed = new Date(dateStr);
  return isNaN(parsed.getTime()) ? new Date() : parsed;
}

// Auxiliary branches map for any additional branch referenced across configs
const ADDITIONAL_BRANCHES: Record<string, { code: string; name: string; city: string; state: string }> = {
  br_vasco: {
    code: 'BR-VAS-008',
    name: 'Vasco Port Branch',
    city: 'Vasco da Gama',
    state: 'Goa',
  },
  br_bkc_mumbai: {
    code: 'BR-BKC-009',
    name: 'Mumbai BKC Regional Hub',
    city: 'Mumbai',
    state: 'Maharashtra',
  },
  br_bengaluru: {
    code: 'BR-BLR-010',
    name: 'Bengaluru Tech Park Branch',
    city: 'Bengaluru',
    state: 'Karnataka',
  },
};

async function main() {
  console.log('🌱 Starting clean slate database seed for Loan MS...');

  // 1. Clean existing records in strict reverse foreign-key dependency order
  console.log('🧹 Cleaning existing tables...');

  // Closures & NOC
  await prisma.closureEvent.deleteMany({});
  await prisma.nocRecord.deleteMany({});
  await prisma.settlementProposal.deleteMany({});
  await prisma.foreclosureQuote.deleteMany({});
  await prisma.loanClosureRequest.deleteMany({});

  // Adjustments & Waivers
  await prisma.adjustmentReversal.deleteMany({});
  await prisma.financialAdjustmentRequest.deleteMany({});
  await prisma.waiverRequest.deleteMany({});
  await prisma.chargeConfiguration.deleteMany({});

  // Restructuring
  await prisma.restructuringEvent.deleteMany({});
  await prisma.restructuringProposal.deleteMany({});
  await prisma.restructuringRequest.deleteMany({});

  // Legal & Recovery
  await prisma.legalNotice.deleteMany({});
  await prisma.legalCaseEvent.deleteMany({});
  await prisma.legalCase.deleteMany({});
  await prisma.legalReview.deleteMany({});
  await prisma.recoveryNegotiation.deleteMany({});
  await prisma.recoveryAssignment.deleteMany({});
  await prisma.recoveryEscalation.deleteMany({});
  await prisma.recoveryAction.deleteMany({});
  await prisma.recoveryCase.deleteMany({});

  // Payments & Collections
  await prisma.unallocatedPayment.deleteMany({});
  await prisma.paymentHistory.deleteMany({});
  await prisma.paymentReversal.deleteMany({});
  await prisma.paymentReceipt.deleteMany({});
  await prisma.paymentAllocation.deleteMany({});
  await prisma.payment.deleteMany({});

  // Loan Servicing & Schedule
  await prisma.loanHistory.deleteMany({});
  await prisma.loanTransaction.deleteMany({});
  await prisma.loanCharge.deleteMany({});
  await prisma.loanRepaymentSetting.deleteMany({});
  await prisma.repaymentSchedule.deleteMany({});
  await prisma.repaymentScheduleVersion.deleteMany({});
  await prisma.loanAccount.deleteMany({});

  // Disbursements
  await prisma.disbursementHistory.deleteMany({});
  await prisma.disbursementTransaction.deleteMany({});
  await prisma.disbursementBeneficiary.deleteMany({});
  await prisma.disbursementRequest.deleteMany({});
  await prisma.disbursement.deleteMany({});

  // Sanctions & Approvals
  await prisma.sanctionLetterVersion.deleteMany({});
  await prisma.sanctionCondition.deleteMany({});
  await prisma.sanction.deleteMany({});
  await prisma.approvalCondition.deleteMany({});
  await prisma.approvalRecord.deleteMany({});
  await prisma.approvalMatrixRule.deleteMany({});

  // Credit Assessment & Applications
  await prisma.creditAssessment.deleteMany({});
  await prisma.loanApplicationFormResponse.deleteMany({});
  await prisma.applicationHistory.deleteMany({});
  await prisma.applicationDocument.deleteMany({});
  await prisma.guarantor.deleteMany({});
  await prisma.coApplicant.deleteMany({});
  await prisma.loanApplication.deleteMany({});

  // Forms & Templates
  await prisma.applicationFormVersion.deleteMany({});
  await prisma.applicationFormTemplate.deleteMany({});

  // Customer & Vault
  await prisma.customerHistory.deleteMany({});
  await prisma.documentItem.deleteMany({});
  await prisma.kycRecord.deleteMany({});
  await prisma.customer.deleteMany({});

  // Master Configuration
  await prisma.adminAuditLog.deleteMany({});
  await prisma.applicationSetting.deleteMany({});
  await prisma.loanProduct.deleteMany({});
  await prisma.user.deleteMany({});
  await prisma.branch.deleteMany({});
  await prisma.role.deleteMany({});

  console.log('✅ All existing tables wiped clean.');

  // 2. Seed Roles
  console.log('🔐 Seeding System Roles...');
  for (const role of INITIAL_ROLES) {
    await prisma.role.create({
      data: {
        id: role.id,
        code: role.code,
        name: role.name,
        description: role.description,
        isSystem: role.isSystemProtected ?? false,
        permissions: role.permissionIds || [],
      },
    });
  }

  // 3. Seed Branches
  console.log('🏢 Seeding Branches...');
  const seededBranchIds = new Set<string>();

  for (const branch of INITIAL_BRANCHES) {
    await prisma.branch.create({
      data: {
        id: branch.id,
        code: branch.code,
        name: branch.name,
        addressLine1: branch.addressLine1,
        addressLine2: branch.addressLine2,
        city: branch.city,
        state: branch.state,
        pinCode: branch.pinCode,
        phone: branch.phone,
        email: branch.email,
        managerId: 'usr_001',
        managerName: 'System Administrator',
        status: branch.status,
        activeLoanCount: 0,
        totalPortfolioValue: 0,
      },
    });
    seededBranchIds.add(branch.id);
  }

  // Additional mapped branches
  for (const [branchId, branchData] of Object.entries(ADDITIONAL_BRANCHES)) {
    if (!seededBranchIds.has(branchId)) {
      await prisma.branch.create({
        data: {
          id: branchId,
          code: branchData.code,
          name: branchData.name,
          city: branchData.city,
          state: branchData.state,
          status: 'ACTIVE',
        },
      });
      seededBranchIds.add(branchId);
    }
  }

  // 4. Seed 1 Admin User
  console.log('👤 Seeding Single Admin User...');
  for (const user of INITIAL_USERS) {
    const branchId = seededBranchIds.has(user.branchId) ? user.branchId : 'br_panjim';
    await prisma.user.create({
      data: {
        id: user.id,
        username: user.username,
        email: user.email,
        firstName: user.firstName,
        lastName: user.lastName,
        employeeId: user.employeeId,
        mobile: user.mobile,
        department: user.department,
        status: (user.status as any) || 'ACTIVE',
        roleId: user.roleId,
        branchId: branchId,
        lastLogin: parseDate(user.lastLogin),
        failedLogins: 0,
      },
    });
    console.log(`   ✓ Admin user seeded: ${user.name} (${user.email} / ${user.username})`);
  }

  // 5. Seed Loan Products Master Data
  console.log('📦 Seeding Loan Products Master Configuration...');
  for (const prod of LOAN_PRODUCTS_CONFIG) {
    await prisma.loanProduct.create({
      data: {
        code: prod.code,
        name: prod.name,
        category: prod.category,
        description: prod.description,
        minAmount: prod.minAmount,
        maxAmount: prod.maxAmount,
        minTenureMonths: prod.minTenureMonths,
        maxTenureMonths: prod.maxTenureMonths,
        baseInterestRate: prod.baseInterestRate,
        allowedFrequencies: prod.allowedFrequencies,
        requiredDocumentTypes: prod.requiredDocumentTypes as any,
        status: 'ACTIVE',
      },
    });
  }

  // 6. Seed Approval Matrix Rules
  console.log('⚖️ Seeding Approval Matrix Rules...');
  for (const rule of INITIAL_APPROVAL_MATRIX_RULES) {
    await prisma.approvalMatrixRule.create({
      data: {
        id: rule.id,
        ruleCode: rule.ruleCode || `RULE-${rule.id}`,
        roleName: rule.approverRoleName || rule.approverRoleId || 'Approver',
        maxApprovalLimit: rule.authorityLimit || rule.maxAmount || 1000000,
        allowedProducts: rule.productCode ? [rule.productCode] : ['ALL'],
        requiresCommittee: rule.canApproveExceptions ?? false,
        isActive: rule.isActive ?? true,
      },
    });
  }

  // 7. Seed Initial System Audit Log
  console.log('📜 Seeding Initial System Audit Entry...');
  await prisma.adminAuditLog.create({
    data: {
      id: 'audit_init_001',
      timestamp: new Date(),
      actorId: 'usr_001',
      actorName: 'System Administrator',
      actorRole: 'System Administrator',
      entityType: 'USER' as any,
      entityId: 'usr_001',
      entityName: 'System Administrator (admin)',
      action: 'SYSTEM_INITIALIZATION',
      details: 'Clean slate initialized. Master configuration seeded with 1 System Administrator account.',
      reason: 'Initial system baseline setup for fresh user onboarding workflow.',
      ipAddress: '127.0.0.1',
    },
  });

  console.log('✨ Fresh slate initialization complete! 1 Admin user and master seed data are ready.');
}

main()
  .catch((e) => {
    console.error('❌ Seeding failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
    await pool.end();
  });
