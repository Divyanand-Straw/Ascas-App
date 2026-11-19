import { Router } from 'express';
import healthRoutes from './health.routes';
import { createAuthRouter, createPersistentAuthService } from '../../modules/auth/auth.routes';

const router = Router();

// Mount feature sub-routers under /api/v1
router.use('/health', healthRoutes);

// In production, instantiate persistent PostgreSQL repositories and SMS provider.
// In development/test, createAuthRouter() uses mock repositories unless explicitly injected.
const authRouter =
  process.env.NODE_ENV === 'production'
    ? createAuthRouter({ authService: createPersistentAuthService() })
    : createAuthRouter();

router.use('/auth', authRouter);

// Future modular routers will be mounted here:
// router.use('/appointments', appointmentRoutes);

export default router;
