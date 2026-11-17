import { Router, Request, Response } from 'express';
import { getAppHealth, getDatabaseHealth } from '../../services/health.service';
import { sendSuccess, sendError } from '../../utils/apiResponse';
import { validateRequest } from '../../middleware/validate';
import { z } from 'zod';

const router = Router();

/**
 * GET /api/v1/health
 * Versioned app health endpoint
 */
router.get('/', (_req: Request, res: Response) => {
  const health = getAppHealth();
  return sendSuccess(res, health, 'IVF Patient App API v1 is operational');
});

/**
 * GET /api/v1/health/database
 * Versioned database health endpoint
 */
router.get('/database', async (_req: Request, res: Response) => {
  try {
    const dbHealth = await getDatabaseHealth();
    return sendSuccess(res, dbHealth, 'Database connection verified successfully');
  } catch (error) {
    return sendError(
      res,
      'Database connection failed',
      503,
      'DATABASE_UNAVAILABLE',
      (error as Error).message
    );
  }
});

/**
 * POST /api/v1/health/validation-test
 * Isolated test route to verify Zod validation middleware behavior (Step 6 verification)
 */
const testValidationSchema = z.object({
  email: z.string().email('Please provide a valid email address'),
  patientAge: z.number().int().min(18, 'Patient must be at least 18 years old'),
});

router.post(
  '/validation-test',
  validateRequest({ body: testValidationSchema }),
  (req: Request, res: Response) => {
    return sendSuccess(res, req.body, 'Validation test passed successfully');
  }
);

export default router;

