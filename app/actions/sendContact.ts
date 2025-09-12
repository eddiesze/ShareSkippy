'use server';

import { z } from 'zod';
import { headers } from 'next/headers';
import { rateLimit } from '@/lib/ratelimit';

const contactSchema = z.object({
  name: z.string().min(2, 'Name must be at least 2 characters'),
  email: z.string().email('Please enter a valid email address'),
  category: z.enum(['general', 'bug', 'safety', 'feature', 'account', 'other']),
  subject: z.string().min(3, 'Subject must be at least 3 characters'),
  message: z.string().min(5, 'Message must be at least 5 characters').max(2000, 'Message must be less than 2000 characters'),
  hp: z.string().optional(), // Honeypot field
});

export async function sendContact(formData: FormData) {
  try {
    // Convert FormData to object
    const data = Object.fromEntries(formData) as Record<string, string>;
    
    // Validate with Zod
    const parsed = contactSchema.safeParse(data);
    if (!parsed.success) {
      return { 
        ok: false, 
        errors: parsed.error.flatten().fieldErrors 
      };
    }

    // Honeypot check - if hp field is filled, it's likely a bot
    if (data.hp && data.hp.trim() !== '') {
      return { ok: true }; // Silently succeed for bots
    }

    // Rate limiting
    const headersList = await headers();
    const ip = headersList.get('x-forwarded-for') ?? 
               headersList.get('x-real-ip') ?? 
               'unknown';
    
    const rateLimitOk = await rateLimit(ip, 'contact:submit', 5, 600); // 5 submissions per 10 minutes
    if (!rateLimitOk) {
      return { 
        ok: false, 
        errors: { 
          _: ['Too many requests. Please try again later.'] 
        } 
      };
    }

    // TODO: Send email via Resend/SMTP or persist in database
    // For now, we'll just log the contact form submission
    console.log('Contact form submission:', {
      name: parsed.data.name,
      email: parsed.data.email,
      category: parsed.data.category,
      subject: parsed.data.subject,
      message: parsed.data.message,
      timestamp: new Date().toISOString(),
      ip: ip
    });

    // In production, you would:
    // 1. Send email via Resend: await resend.emails.send({...})
    // 2. Or save to database: await db.contactSubmissions.create({...})
    // 3. Or send to a webhook/API endpoint

    return { ok: true };

  } catch (error) {
    console.error('Error processing contact form:', error);
    return { 
      ok: false, 
      errors: { 
        _: ['An unexpected error occurred. Please try again.'] 
      } 
    };
  }
}
