import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { prisma } from '../utils/prisma';
import { ApiError, successResponse, paginatedResponse } from '../utils/apiError';
import { authenticate } from '../middleware/auth';
import { validate } from '../middleware/validate';

const router = Router();
router.use(authenticate);

const CrewMemberSchema = z.object({
  firstName: z.string().min(1),
  lastName: z.string().min(1),
  email: z.string().email().optional(),
  phone: z.string().optional(),
  role: z.string().min(1),
  hourlyRate: z.number().nonnegative().optional(),
  isSubcontractor: z.boolean().optional(),
  skills: z.array(z.string()).optional(),
  certifications: z.array(z.string()).optional(),
});

const TimeEntrySchema = z.object({
  jobId: z.string(),
  date: z.string().datetime(),
  hoursWorked: z.number().positive(),
  notes: z.string().optional(),
});

// ─── GET /crew ────────────────────────────────────────────────────────────────
router.get('/', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const businessId = req.user!.businessId;
    const page = parseInt(req.query.page as string) || 1;
    const limit = parseInt(req.query.limit as string) || 20;
    const isActive = req.query.isActive !== 'false';

    const [total, members] = await Promise.all([
      prisma.crewMember.count({ where: { businessId, isActive } }),
      prisma.crewMember.findMany({
        where: { businessId, isActive },
        orderBy: { lastName: 'asc' },
        skip: (page - 1) * limit,
        take: limit,
        include: {
          _count: { select: { assignments: true, timeEntries: true } },
        },
      }),
    ]);

    res.json(paginatedResponse(members, total, page, limit));
  } catch (error) {
    next(error);
  }
});

// ─── GET /crew/:id ────────────────────────────────────────────────────────────
router.get('/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const businessId = req.user!.businessId;
    const member = await prisma.crewMember.findFirst({
      where: { id: req.params.id, businessId },
      include: {
        assignments: { include: { job: { select: { id: true, title: true, status: true, scheduledDate: true } } }, orderBy: { createdAt: 'desc' }, take: 20 },
        timeEntries: { orderBy: { date: 'desc' }, take: 30 },
      },
    });

    if (!member) throw ApiError.notFound('Crew member not found');
    res.json(successResponse(member));
  } catch (error) {
    next(error);
  }
});

// ─── POST /crew ───────────────────────────────────────────────────────────────
router.post('/', validate(CrewMemberSchema), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const businessId = req.user!.businessId;
    const member = await prisma.crewMember.create({
      data: { ...req.body, businessId },
    });
    res.status(201).json(successResponse(member, 'Crew member added'));
  } catch (error) {
    next(error);
  }
});

// ─── PUT /crew/:id ────────────────────────────────────────────────────────────
router.put('/:id', validate(CrewMemberSchema.partial()), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const businessId = req.user!.businessId;
    const existing = await prisma.crewMember.findFirst({ where: { id: req.params.id, businessId } });
    if (!existing) throw ApiError.notFound('Crew member not found');

    const member = await prisma.crewMember.update({ where: { id: req.params.id }, data: req.body });
    res.json(successResponse(member, 'Crew member updated'));
  } catch (error) {
    next(error);
  }
});

// ─── DELETE /crew/:id ─────────────────────────────────────────────────────────
router.delete('/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const businessId = req.user!.businessId;
    const existing = await prisma.crewMember.findFirst({ where: { id: req.params.id, businessId } });
    if (!existing) throw ApiError.notFound('Crew member not found');

    // Soft delete
    await prisma.crewMember.update({ where: { id: req.params.id }, data: { isActive: false } });
    res.json(successResponse(null, 'Crew member deactivated'));
  } catch (error) {
    next(error);
  }
});

// ─── POST /crew/:id/assign ────────────────────────────────────────────────────
router.post('/:id/assign', validate(z.object({ jobId: z.string(), role: z.string().optional() })), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const businessId = req.user!.businessId;
    const [member, job] = await Promise.all([
      prisma.crewMember.findFirst({ where: { id: req.params.id, businessId } }),
      prisma.job.findFirst({ where: { id: req.body.jobId, businessId } }),
    ]);

    if (!member) throw ApiError.notFound('Crew member not found');
    if (!job) throw ApiError.notFound('Job not found');

    const assignment = await prisma.crewAssignment.create({
      data: { crewMemberId: req.params.id, jobId: req.body.jobId, role: req.body.role },
    });
    res.status(201).json(successResponse(assignment, 'Crew member assigned to job'));
  } catch (error) {
    next(error);
  }
});

// ─── POST /crew/time-entry ────────────────────────────────────────────────────
router.post('/time-entry', validate(TimeEntrySchema.extend({ crewMemberId: z.string() })), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const businessId = req.user!.businessId;
    const { crewMemberId, jobId, date, hoursWorked, notes } = req.body;

    const [member, job] = await Promise.all([
      prisma.crewMember.findFirst({ where: { id: crewMemberId, businessId } }),
      prisma.job.findFirst({ where: { id: jobId, businessId } }),
    ]);

    if (!member) throw ApiError.notFound('Crew member not found');
    if (!job) throw ApiError.notFound('Job not found');

    const entry = await prisma.timeEntry.create({
      data: { crewMemberId, jobId, date: new Date(date), hoursWorked, notes },
    });
    res.status(201).json(successResponse(entry, 'Time entry recorded'));
  } catch (error) {
    next(error);
  }
});

export default router;
