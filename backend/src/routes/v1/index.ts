import { Router } from 'express';
import healthRoutes from './health.routes';
import authRoutes from '../../modules/auth/auth.routes';

const router = Router();

// Mount feature sub-routers under /api/v1
router.use('/health', healthRoutes);
router.use('/auth', authRoutes);

// Future modular routers will be mounted here:
// router.use('/appointments', appointmentRoutes);

export default router;
